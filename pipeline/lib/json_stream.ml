let db_save ~conninfo benchmark output =
  output
  |> Current_bench_json.to_list
  |> List.iter (fun (benchmark_name, version, results) ->
         results
         |> List.mapi (fun test_index res ->
                benchmark ~version ~benchmark_name ~test_index res)
         |> List.iter (Models.Benchmark.Db.insert ~conninfo))

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

type json_parser = {
  current : Buffer.t;
  stack : char list;
  lines : int;
  start_line : int;
}

let json_step stack chr =
  match (stack, chr) with
  | [], '\n' -> [ '\n' ]
  | [], '\r' -> [ '\r' ]
  | [], _ -> []
  | [ '\r' ], '\r' -> [ '\r' ]
  | [ '\r' ], '\n' -> [ '\n' ]
  | [ '\r' ], '{' -> [ '{' ]
  | [ '\r' ], _ -> []
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

let make_json_parser () =
  { current = Buffer.create 16; stack = [ '\n' ]; lines = 1; start_line = 1 }

let json_step state chr =
  let state =
    match chr with
    | '\r' -> { state with lines = state.lines + 1 }
    | '\n' when not (state.stack = [ '\r' ]) ->
        { state with lines = state.lines + 1 }
    | _ -> state
  in
  match json_step state.stack chr with
  | [] ->
      if Buffer.length state.current = 0
      then (None, { state with stack = [] })
      else (
        Buffer.add_char state.current chr;
        let str = Buffer.contents state.current in
        let st = make_json_parser () in
        ( Some str,
          { st with lines = state.lines; start_line = state.start_line } ))
  | hd :: _ as stack ->
      if (chr <> '\n' && chr <> '\r') || hd = '"'
      then Buffer.add_char state.current chr;
      let start_line =
        if state.stack = [] || state.stack = [ '\r' ]
        then state.lines
        else state.start_line
      in
      (None, { state with start_line; stack })

let json_steps (parsed, state) str =
  String.fold_left
    (fun (parsed, state) chr ->
      let opt_json, state = json_step state chr in
      let parsed =
        match opt_json with
        | Some json -> (json, (state.start_line, state.lines)) :: parsed
        | None -> parsed
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
  type t = {
    config : Config.t;
    conninfo : string;
    repository : Repository.t;
    serial_id : int;
    worker : string;
    docker_image : string;
  }

  let id = "db-save"
  let pp h (job_id, _) = Fmt.pf h "db-save %s" job_id

  module Key = struct
    type t = Current.job_id

    let digest t : string = t
  end

  module Value = Current.Unit
  module Outcome = Current.String

  let auto_cancel = true

  let to_slack ~config job_id = function
    | [], [] -> ":x: empty :x:"
    | cb, failures ->
        let failures_output =
          List.map
            (fun (raw, (start, stop), error) ->
              let url = Config.job_url ~config job_id start stop in
              Printf.sprintf ":question: *<%s|%i-%i `%s`>* `%s`" url start stop
                error raw)
            failures
        in
        let cb_output =
          let jsons = List.map Current_bench_json.to_json cb in
          "```" ^ Yojson.Safe.to_string (`List jsons) ^ "```"
        in
        String.concat "\n" ("" :: cb_output :: failures_output)

  let json_merge_lines json (start, end_) =
    Yojson.Safe.Util.combine json
      (`Assoc [ ("lines", `Tuple [ `Int start; `Int end_ ]) ])

  let publish { config; conninfo; repository; serial_id; worker; docker_image }
      job worker_job_id () =
    let open Lwt.Infix in
    Current.Job.start job ~level:Current.Level.Above_average >>= fun () ->
    let run_at = Ptime_clock.now () in
    let build_job_id = Some worker_job_id in
    let run_job_id = Some worker_job_id in
    let json_stream = job_output_stream worker_job_id in
    Lwt_stream.fold
      (fun parsed (cb, failures) ->
        let jsons, json_failures =
          parsed
          |> List.rev
          |> List.partition_map (fun (json, range) ->
                 try
                   let json = Yojson.Safe.from_string json in
                   Left (json_merge_lines json range)
                 with exn -> Right (json, range, Printexc.to_string exn))
        in
        let jsons = Current_bench_json.of_list jsons in
        let cb = Current_bench_json.Latest.merge cb jsons in
        let duration = Ptime.diff (Ptime_clock.now ()) run_at in
        let () =
          db_save ~conninfo
            (Models.Benchmark.make ~duration ~run_at ~repository ~worker
               ~docker_image ?build_job_id ?run_job_id)
            cb
        in
        (cb, List.rev_append json_failures failures))
      json_stream ([], [])
    >>= fun results ->
    Storage.record_success ~conninfo ~serial_id;
    let output = to_slack ~config worker_job_id results in
    Lwt.return (Ok output)
end

module SC = Current_cache.Output (Save)

let save ~config ~conninfo ~repository ~serial_id ~worker ~docker_image job_id =
  let open Current.Syntax in
  Current.component "db-save"
  |> let> job_id in
     match job_id with
     | None -> Current_incr.const (Error (`Active `Ready), None)
     | Some job_id ->
         SC.set
           {
             Save.config;
             conninfo;
             repository;
             serial_id;
             worker;
             docker_image;
           }
           job_id ()
