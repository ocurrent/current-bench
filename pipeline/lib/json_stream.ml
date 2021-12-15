let validate_json json_list =
  Current_bench_json.(validate (List.map of_json json_list))

let db_save ~conninfo benchmark output =
  Storage.with_db ~conninfo (fun db ->
      output
      |> Json_util.parse_many
      |> validate_json
      |> Hashtbl.iter (fun benchmark_name (version, results) ->
             results
             |> List.mapi (fun test_index res ->
                    benchmark ~version ~benchmark_name ~test_index res)
             |> List.iter (Models.Benchmark.Db.insert db)))

let max_log_chunk_size = 102400L (* 100K at a time *)

let read ~start path =
  let ch = open_in_bin (Fpath.to_string path) in
  Fun.protect ~finally:(fun () -> close_in ch) @@ fun () ->
  let len = LargeFile.in_channel_length ch in
  let ( + ) = Int64.add in
  let ( - ) = Int64.sub in
  let start = if start < 0L then len + start else start in
  let start = if start < 0L then 0L else if start > len then len else start in
  LargeFile.seek_in ch start;
  let len = min max_log_chunk_size (len - start) in
  (really_input_string ch (Int64.to_int len), start + len)

type json_parser = { current : Buffer.t; stack : char list }

let json_step stack chr =
  match (stack, chr) with
  | [], '\n' -> [ '\n' ]
  | [], _ -> []
  | [ '\n' ], '\n' -> [ '\n' ]
  | [ '\n' ], '{' -> [ '{' ]
  | [ '\n' ], _ -> []
  | '\\' :: stack, _ -> stack
  | '{' :: stack, '}' -> stack
  | '[' :: stack, ']' -> stack
  | '"' :: stack, '"' -> stack
  | '"' :: stack, '\\' -> '\\' :: stack
  | _, (('{' | '[' | '"') as chr) -> chr :: stack
  | _ -> stack

let make_json_parser () = { current = Buffer.create 16; stack = [] }

let json_step state chr =
  match json_step state.stack chr with
  | [] ->
      if Buffer.length state.current = 0
      then (None, { state with stack = [] })
      else (
        Buffer.add_char state.current chr;
        let str = Buffer.contents state.current in
        (Some str, make_json_parser ()))
  | hd :: _ as stack ->
      if hd <> '\n' then Buffer.add_char state.current chr;
      (None, { state with stack })

let json_steps (parsed, state) str =
  String.fold_left
    (fun (parsed, state) chr ->
      let opt_json, state = json_step state chr in
      let parsed =
        match opt_json with Some json -> json :: parsed | None -> parsed
      in
      (parsed, state))
    (parsed, state) str

let job_output_stream job_id =
  match Current.Job.log_path job_id with
  | Error (`Msg msg) ->
      Logs.err (fun log -> log "worker %S: %s" job_id msg);
      Lwt_stream.of_list []
  | Ok path ->
      let position = ref 0L in
      let state = ref (make_json_parser ()) in
      Lwt_stream.from (fun () ->
          let rec aux () =
            let start = !position in
            match read ~start path with
            | "", _ -> try_again ()
            | data, next -> (
                position := next;
                let parsed, st = json_steps ([], !state) data in
                state := st;
                match parsed with
                | [] -> try_again ()
                | _ -> Lwt.return_some parsed)
          and try_again () =
            match Current.Job.lookup_running job_id with
            | None -> Lwt.return_none
            | Some job ->
                let open Lwt.Infix in
                Current.Job.wait_for_log_data job >>= aux
          in
          aux ())

module Save = struct
  type t = { conninfo : string; repository : Repository.t }

  let id = "db-save"

  let pp h (job_id, _) = Fmt.pf h "db-save %s" job_id

  module Key = struct
    type t = Current.job_id

    let digest t : string = t
  end

  module Value = Current.Unit
  module Outcome = Current.String

  let auto_cancel = true

  let publish { conninfo; repository } job worker_job_id () =
    let open Lwt.Infix in
    Current.Job.start job ~level:Current.Level.Above_average >>= fun () ->
    let run_at = Ptime_clock.now () in
    let json_stream = job_output_stream worker_job_id in
    Lwt_stream.fold List.rev_append json_stream [] >>= fun outputs ->
    let output = String.concat "\n" (List.rev outputs) in
    let build_job_id = Some worker_job_id in
    let run_job_id = Some worker_job_id in
    let duration = Ptime.diff (Ptime_clock.now ()) run_at in
    let () =
      db_save ~conninfo
        (Models.Benchmark.make ~duration ~run_at ~repository ?build_job_id
           ?run_job_id)
        output
    in
    Lwt.return (Ok output)
end

module SC = Current_cache.Output (Save)

let save ~conninfo ~repository job_id =
  let open Current.Syntax in
  Current.component "db-save"
  |> let> job_id = job_id in
     match job_id with
     | None -> Current_incr.const (Error (`Active `Ready), None)
     | Some job_id -> SC.set { Save.conninfo; repository } job_id ()
