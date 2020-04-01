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

open! Postgresql

let populate_postgres conninfo json_string =
  try
    let c = new connection ~conninfo () in
    let _ =
      c#exec ~expect:[ Command_ok ]
        ("insert into index(benchmarks_data) values ( '" ^ json_string ^ "' )")
    in
    c#finish
  with
  | Error e -> prerr_endline (string_of_error e)
  | e -> prerr_endline (Printexc.to_string e)
