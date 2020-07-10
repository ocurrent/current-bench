(*To keep all the utis function for reading files, manipulating jsons, etc.*)

let read_fpath p = Bos.OS.File.read p |> Rresult.R.error_msg_to_invalid_arg

let merge_json repo commit json =
  Yojson.Basic.pretty_to_string
    (`Assoc
      [ ("repo", `String repo); ("commit", `String commit); ("result", json) ])

let read_file path =
  let ch = open_in_bin path in
  Fun.protect
    (fun () ->
      let len = in_channel_length ch in
      really_input_string ch len)
    ~finally:(fun () -> close_in ch)

open Yojson.Basic.Util

let format_benchmark_data commit bench_name time mbs_per_sec ops_per_sec
    timestamp pr =
  "('"
  ^ commit
  ^ "', '"
  ^ bench_name
  ^ "',"
  ^ time
  ^ ", "
  ^ mbs_per_sec
  ^ ", "
  ^ ops_per_sec
  ^ ","
  ^ timestamp
  ^ ",'"
  ^ pr
  ^ "') "

let get_repo json = Yojson.Basic.from_string json |> member "repo" |> to_string

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
        (format_benchmark_data commit bench_name
           (metrics |> member "time" |> to_float |> string_of_float)
           (metrics |> member "mbs_per_sec" |> to_float |> string_of_float)
           (metrics |> member "ops_per_sec" |> to_float |> string_of_float))
          (Unix.time () |> string_of_float)
          pr_str)
      bench_objects bench_names
  in
  String.concat " , " result_string

open! Postgresql

let populate_postgres conninfo commit json_string pr_num =
  try
    let repository = get_repo json_string in
    let c = new connection ~conninfo () in
    let _ =
      c#exec ~expect:[ Command_ok ]
        ( "insert into benchmarks(repositories, commits, json_data) values ( '"
        ^ repository
        ^ "', '"
        ^ commit
        ^ "', '"
        ^ json_string
        ^ "' )" )
    in
    let pr_str = Printf.sprintf "%s/%d" repository pr_num in
    let data_to_insert =
      construct_data_for_benchmarks_run commit json_string pr_str
    in
    let _ =
      c#exec ~expect:[ Command_ok ]
        ( "insert into benchmarksrun(commits, name, time, mbs_per_sec, \
           ops_per_sec, timestamp, branch) values "
        ^ data_to_insert )
    in
    c#finish
  with
  | Error e -> prerr_endline (string_of_error e)
  | e -> prerr_endline (Printexc.to_string e)
