let () = Printexc.record_backtrace true

let read_fpath p = Bos.OS.File.read p |> Rresult.R.error_msg_to_invalid_arg

let get_branch_name branch =
  let prefix = "refs/heads/" in
  let len_prefix = String.length prefix in
  String.sub branch len_prefix (String.length branch - len_prefix)

let stale_timestamp () =
  let two_weeks_in_seconds = 1209600. in
  let curr_gmt = Unix.gmtime (Unix.time () -. two_weeks_in_seconds) in
  let year = curr_gmt.tm_year + 1900 in
  let month = curr_gmt.tm_mon + 1 in
  let day = curr_gmt.tm_mday in
  let hour = curr_gmt.tm_hour in
  let min = curr_gmt.tm_min in
  let sec = curr_gmt.tm_sec in
  Format.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" year month day hour min sec

let stream_to_list stream =
  let acc = ref [] in
  Stream.iter (fun x -> acc := x :: !acc) stream;
  List.rev !acc

let parse_jsons string = stream_to_list (Yojson.Safe.stream_from_string string)
