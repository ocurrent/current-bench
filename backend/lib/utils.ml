(*To keep all the utils function for reading files, manipulating jsons, etc.*)

let read_fpath p = Bos.OS.File.read p |> Rresult.R.error_msg_to_invalid_arg

open Yojson.Basic.Util

let merge_json ~repo ~owner ~commit json =
  Yojson.Basic.pretty_to_string
    (`Assoc
      [
        ("repo", `String (Printf.sprintf "%s/%s" owner repo));
        ("commit", `String commit);
        ("result", Yojson.Basic.from_string json);
      ])

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
    c#finish
  with
  | Error e -> prerr_endline (string_of_error e)
  | e -> prerr_endline (Printexc.to_string e)
