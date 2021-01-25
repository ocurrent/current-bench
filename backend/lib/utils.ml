(*To keep all the utils function for reading files, manipulating jsons, etc.*)

let read_fpath p = Bos.OS.File.read p |> Rresult.R.error_msg_to_invalid_arg

let stream_to_list stream =
  let acc = ref [] in
  Stream.iter (fun x -> acc := x :: !acc) stream;
  List.rev !acc

module Json_utils = struct
  let parse_many string = stream_to_list (Yojson.Safe.stream_from_string string)
end

module Sql_utils = struct
  type value = string

  let option f = function Some x -> f x | None -> "NULL"

  let time x = "to_timestamp(" ^ string_of_float (Ptime.to_float_s x) ^ ")"

  let span x =
    let seconds = Ptime.Span.to_float_s x in
    "make_interval(secs => " ^ string_of_float seconds ^ ")"

  let string x = "'" ^ x ^ "'"

  let int = string_of_int

  let json x = "'" ^ Yojson.Safe.to_string x ^ "'"
end

open Yojson.Safe.Util

let construct_data_for_benchmarks_run commit json pr_str =
  let bench_objects =
    Yojson.Safe.from_string json
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
        let time = metrics |> member "time" |> to_number in
        let mbs_per_sec = metrics |> member "mbs_per_sec" |> to_number in
        let ops_per_sec = metrics |> member "ops_per_sec" |> to_number in
        Fmt.str "('%s', '%s', %f, %f, %f, %f, '%s')" commit bench_name time
          mbs_per_sec ops_per_sec (Unix.time ()) pr_str)
      bench_objects bench_names
  in
  String.concat " , " result_string

let merge_json ~repo ~owner ~commit multi_json =
  let json_result_to_string result =
    Yojson.Safe.pretty_to_string
      (`Assoc
        [
          ("repo", `String (Printf.sprintf "%s/%s" owner repo));
          ("commit", `String commit);
          ("result", result);
        ])
  in
  let json_results = Json_utils.parse_many multi_json in
  List.map json_result_to_string json_results

open! Postgresql

let populate_postgres ~conninfo ~commit ~json_string ~pr_info =
  try
    let c = new connection ~conninfo () in
    let data_to_insert =
      construct_data_for_benchmarks_run commit json_string pr_info
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
