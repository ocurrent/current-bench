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

let num_file_dir path =
  let dir_handle = Unix.opendir path in
  let rec loop acc =
    try
      let _ = Unix.readdir dir_handle in
      loop (acc + 1)
    with End_of_file -> acc
  in
  let num = loop 0 in
  let () = Unix.closedir dir_handle in
  num

let create_tmp_host repo commit_hash =
  let path = "/data/tmp/" ^ repo in
  let () =
    if not (Sys.file_exists path) then try Unix.mkdir path 0o777 with _ -> ()
  in
  let path = path ^ "/" ^ commit_hash in
  let () =
    if not (Sys.file_exists path) then try Unix.mkdir path 0o777 with _ -> ()
  in
  let files = num_file_dir path in
  let file_name = string_of_int files in
  let path = path ^ "/" ^ file_name ^ ".json" in
  let oc = open_out path in
  let () = Unix.chmod path 0o666 in
  let () = close_out oc in
  Fpath.(v path)

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
