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

let is_whitespace = function '\n' | ' ' | '\t' | '\r' -> true | _ -> false
let is_numeric = function '0' .. '9' | '-' | '.' | 'e' -> true | _ -> false

type automata =
  | BeforeID  (** Curly brace received, waiting for a string id *)
  | InArray  (** Waiting for a value or a \] *)
  | InString  (** Inside the identifier: "foo" *)
  | InNumber  (** Parsing the full number *)
  | Escaped  (** Right after a \ inside a string *)
  | AfterID  (** After string, waiting for a colon *)
  | BeforeValue  (** After colon, waiting for any value on the right side *)
  | AfterValue  (** After value, waiting for a comma or closing bracket *)
  | BoolT  (** Ugly but seems necessary *)
  | BoolR
  | BoolU
  | BoolF
  | BoolA
  | BoolL
  | BoolS
  | NullN
  | NullU
  | NullL

exception Finished_JSON
exception Invalid_JSON

type json_parser = {
  current : Buffer.t;
  stack : automata list;
  lines : int;
  start_line : int;
  carriage_seen : bool;
}

let json_step_aux stack chr =
  if is_whitespace chr
  then stack
  else
    match (stack, chr) with
    (* Initial state *)
    | [], '{' -> [ BeforeID ]
    | [], _ -> []
    (* Bracket open or after a comma *)
    | BeforeID :: st, '"' -> InString :: AfterID :: st
    | [ BeforeID ], '}' -> raise Finished_JSON
    | BeforeID :: st, '}' -> st
    | BeforeID :: _, _ -> raise Invalid_JSON
    (* Inside string *)
    | InString :: _, '\\' -> Escaped :: stack
    | Escaped :: st, _ -> st
    | InString :: st, '"' -> st
    | InString :: _, _ -> stack
    (* After string *)
    | AfterID :: st, ':' -> BeforeValue :: st
    | AfterID :: _, _ -> raise Invalid_JSON
    (* After value *)
    | AfterValue :: InArray :: st, ']' -> AfterValue :: st
    | AfterValue :: InArray :: st, ',' -> BeforeValue :: InArray :: st
    | [ AfterValue ], '}' -> raise Finished_JSON
    | AfterValue :: st, '}' -> st
    | AfterValue :: st, ',' -> BeforeID :: st
    | AfterValue :: _, _ -> raise Invalid_JSON
    (* Before value *)
    | BeforeValue :: st, '"' -> InString :: AfterValue :: st
    | BeforeValue :: st, '{' -> BeforeID :: AfterValue :: st
    (*     Booleans + null *)
    | BeforeValue :: st, 't' -> BoolT :: st
    | BoolT :: st, 'r' -> BoolR :: st
    | BoolR :: st, 'u' -> BoolU :: st
    | BoolU :: st, 'e' -> AfterValue :: st
    | BeforeValue :: st, 'f' -> BoolF :: st
    | BoolF :: st, 'a' -> BoolA :: st
    | BoolA :: st, 'l' -> BoolL :: st
    | BoolL :: st, 's' -> BoolS :: st
    | BoolS :: st, 'e' -> AfterValue :: st
    | BeforeValue :: st, 'n' -> NullN :: st
    | NullN :: st, 'u' -> NullU :: st
    | NullU :: st, 'l' -> NullL :: st
    | NullL :: st, 'l' -> AfterValue :: st
    | BoolT :: _, _
    | BoolR :: _, _
    | BoolU :: _, _
    | BoolF :: _, _
    | BoolA :: _, _
    | BoolL :: _, _
    | BoolS :: _, _
    | NullN :: _, _
    | NullU :: _, _
    | NullL :: _, _ ->
        raise Invalid_JSON
    (*     Arrays *)
    | BeforeValue :: st, '[' -> BeforeValue :: InArray :: st
    (*     Impossible case *)
    | InArray :: _, _ -> failwith "InArray shouldn't be on top of the stack"
    (*     Numbers *)
    | BeforeValue :: st, chr when is_numeric chr -> InNumber :: st
    | InNumber :: _, chr when is_numeric chr -> stack
    | InNumber :: InArray :: st, ']' -> AfterValue :: st
    | InNumber :: InArray :: st, ',' -> BeforeValue :: InArray :: st
    | [ InNumber ], '}' -> raise Finished_JSON
    | InNumber :: st, '}' -> st
    | InNumber :: st, ',' -> BeforeID :: st
    | InNumber :: _, _ -> raise Invalid_JSON
    | BeforeValue :: _, _ -> raise Invalid_JSON

let make_json_parser ?(lines = 1) ?(start_line = 1) () =
  {
    current = Buffer.create 16;
    stack = [];
    lines;
    start_line;
    carriage_seen = false;
  }

let json_step state chr =
  let state =
    match (chr, state.carriage_seen) with
    | '\r', _ -> { state with lines = state.lines + 1; carriage_seen = true }
    | '\n', false -> { state with lines = state.lines + 1 }
    | _ -> { state with carriage_seen = false }
  in
  match json_step_aux state.stack chr with
  | [] -> (None, { state with start_line = state.lines; stack = [] })
  | exception Invalid_JSON ->
      (None, make_json_parser ~lines:state.lines ~start_line:state.start_line ())
  | exception Finished_JSON ->
      Buffer.add_char state.current chr;
      let str = Buffer.contents state.current in
      ( Some str,
        make_json_parser ~lines:state.lines ~start_line:state.start_line () )
  | hd :: _ as stack ->
      if hd = InString || (chr <> '\n' && chr <> '\r')
      then Buffer.add_char state.current chr;
      (None, { state with stack })

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

let json_full str =
  let state = make_json_parser () in
  let parsed, _ = json_steps ([], state) str in
  parsed

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
          let jsons = List.map Current_bench_json.Latest.to_json cb in
          "```" ^ Yojson.Safe.to_string (`List jsons) ^ "```"
        in
        String.concat "\n" ("" :: cb_output :: failures_output)

  let json_merge_lines (start, finish) json =
    Yojson.Safe.Util.combine json
      (`Assoc [ ("lines", `Tuple [ `Int start; `Int finish ]) ])

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
          |> List.fold_left
               (fun (jsons, exns) (json, range) ->
                 try
                   ( json
                     |> Yojson.Safe.from_string
                     |> json_merge_lines range
                     |> Current_bench_json.Latest.of_json
                     |> Current_bench_json.Latest.add jsons,
                     exns )
                 with exn ->
                   (jsons, (json, range, Printexc.to_string exn) :: exns))
               ([], [])
        in
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
