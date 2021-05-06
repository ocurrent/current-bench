let () = Printexc.record_backtrace true

let read_fpath p = Bos.OS.File.read p |> Rresult.R.error_msg_to_invalid_arg

let get_branch_name branch =
  let prefix = "refs/heads/" in
  let len_prefix = String.length prefix in
  String.sub branch len_prefix (String.length branch - len_prefix)
