(*To keep all the utis function for reading files, manipulating jsons, etc.*)

let read_fpath p = Bos.OS.File.read p |> Rresult.R.error_msg_to_invalid_arg

let write_fpath p content =
  Bos.OS.File.write p content |> Rresult.R.error_msg_to_invalid_arg

open Yojson.Basic.Util

let get_commit_string body =
  [ Yojson.Basic.from_string body ]
  |> filter_member "commit"
  |> filter_member "tree"
  |> filter_member "sha"
  |> filter_string
  |> List.hd

let get_commit repo owner user token =
  let headers = [ ("-u", user ^ ":" ^ token) ] in
  let url =
    "https://api.github.com/repos/" ^ owner ^ "/" ^ repo ^ "/commits/master"
  in
  match Curly.(run (Request.make ~headers ~url ~meth:`GET ())) with
  | Ok x -> get_commit_string x.Curly.Response.body
  | Error _ -> "failed"

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

let format_benchmark_data commit name time mbs_per_sec ops_per_sec timestamp =
  "('"
  ^ commit
  ^ "', '"
  ^ name
  ^ "',"
  ^ time
  ^ ", "
  ^ mbs_per_sec
  ^ ", "
  ^ ops_per_sec
  ^ ","
  ^ timestamp
  ^ ") "

let get_repo json = Yojson.Basic.from_string json |> member "repo" |> to_string

let get_data_from_json commit json =
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
          (string_of_float (Unix.time ())))
      bench_objects bench_names
  in
  String.concat "," result_string

open! Postgresql

let populate_postgres conninfo commit json_string =
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
    let data_to_insert = get_data_from_json commit json_string in
    let _ =
      c#exec ~expect:[ Command_ok ]
        ( "insert into benchmarksrun(commits, name, time, mbs_per_sec, \
           ops_per_sec, timestamp) values "
        ^ data_to_insert )
    in
    c#finish
  with
  | Error e -> prerr_endline (string_of_error e)
  | e -> prerr_endline (Printexc.to_string e)
