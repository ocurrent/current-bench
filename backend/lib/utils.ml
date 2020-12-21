(*To keep all the utils function for reading files, manipulating jsons, etc.*)

let read_fpath p = Bos.OS.File.read p |> Rresult.R.error_msg_to_invalid_arg

open Yojson.Basic.Util

let construct_data_for_benchmarks_run commit json pr_str =
  let bench_objects =
    Yojson.Basic.from_string json
    |> member "result"
    |> member "results"
    |> to_list
  in
  let bench_names =
    List.map (fun json -> json |> member "name" |> to_string) bench_objects
  in
  let result_string =
    List.map2
      (fun json bench_name ->
        let metrics = json |> member "metrics" in
        let time = metrics |> member "time" |> to_float in
        let mbs_per_sec = metrics |> member "mbs_per_sec" |> to_float in
        let ops_per_sec = metrics |> member "ops_per_sec" |> to_float in
        Fmt.str "('%s', '%s', %f, %f, %f, %f, '%s')" commit bench_name time
          mbs_per_sec ops_per_sec (Unix.time ()) pr_str)
      bench_objects bench_names
  in
  String.concat " , " result_string

let stream_to_list stream =
  let acc = ref [] in
  Stream.iter (fun x -> acc := x :: !acc) stream;
  List.rev !acc

let json_parse_many string =
  stream_to_list (Yojson.Basic.stream_from_string string)

let merge_json ~repo ~owner ~commit multi_json =
  let json_result_to_string result =
    Yojson.Basic.pretty_to_string
      (`Assoc
        [
          ("repo", `String (Printf.sprintf "%s/%s" owner repo));
          ("commit", `String commit);
          ("result", result);
        ])
  in
  let json_results = json_parse_many multi_json in
  List.map json_result_to_string json_results

let get_repo json = Yojson.Basic.from_string json |> member "repo" |> to_string

open! Postgresql

let populate_postgres ~conninfo ~commit ~json_string ~pr_info =
  try
    let repository = get_repo json_string in
    let c = new connection ~conninfo () in
    let _ =
      c#exec ~expect:[ Command_ok ]
        (Fmt.str
           "insert into benchmarks(repositories, commits, json_data, \
            timestamp, branch) values ('%s', '%s', '%s', '%f', '%s')"
           repository commit json_string (Unix.time ()) pr_info)
    in
    let data_to_insert =
      construct_data_for_benchmarks_run commit json_string pr_info
    in
    let _ =
      c#exec ~expect:[ Command_ok ]
        ("insert into benchmarksrun(commits, name, time, mbs_per_sec, \
          ops_per_sec, timestamp, branch) values "
        ^ data_to_insert)
    in
    c#finish
  with
  | Error e -> prerr_endline (string_of_error e)
  | e -> prerr_endline (Printexc.to_string e)
