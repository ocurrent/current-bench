module File_exists = struct
  type t = unit

  let id = "git-file-exists"

  module Key = struct
    type t = { commit : Current_git.Commit.t; filename : Fpath.t }

    let to_json t =
      `Assoc
        [
          ("commit", `String (Current_git.Commit.hash t.commit));
          ("filename", `String (Fpath.to_string t.filename));
        ]

    let digest t = Yojson.Safe.to_string (to_json t)

    let pp f t = Yojson.Safe.pretty_print f (to_json t)
  end

  module Value = struct
    type t = bool

    let marshal t = if t then "true" else "false"

    let unmarshal = function
      | "true" -> true
      | "false" -> false
      | _ -> invalid_arg "not a boolean"
  end

  open Lwt.Infix

  let build () job { Key.commit; filename = target } =
    Current.Job.start job ~level:Current.Level.Average >>= fun () ->
    Current_git.with_checkout ~job commit @@ fun dir ->
    let filename = Fpath.(to_string (dir // target)) in
    Lwt_unix.file_exists filename >>= fun ok -> Lwt.return (Ok ok)

  let pp f key = Fmt.pf f "@[<v2>git file exists %a@]" Key.pp key

  let auto_cancel = true
end

module Cache = Current_cache.Make (File_exists)

let pp_commit = Fmt.(string)

let file_exists ~commit filename =
  let open Current.Syntax in
  Current.component "file-exists %S" (Fpath.to_string filename)
  |> let> commit = commit in
     Cache.get () { File_exists.Key.commit; filename }
