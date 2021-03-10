let () = Printexc.record_backtrace true

let read_fpath p = Bos.OS.File.read p |> Rresult.R.error_msg_to_invalid_arg
