open Current.Syntax
module Docker = Current_docker.Default

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

let file_exists ~src filename =
  Current.component "file-exists %S" (Fpath.to_string filename)
  |> let> commit = src in
     Cache.get () { File_exists.Key.commit; filename }

(* Generate a Dockerfile for building all the opam packages in the build context. *)
let dockerfile ~base ~repository =
  let opam_dependencies =
    (* FIXME: This should be supported by a custom Dockerfiles. *)
    if String.equal repository "dune" then
      "opam install ./dune-bench.opam -y --deps-only  -t"
    else "opam install -y --deps-only -t ."
  in
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run
       "sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
        liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev \
        libpcre3-dev"
  @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"bench-dir" ()
  @@ workdir "bench-dir"
  @@ run "opam remote add origin https://opam.ocaml.org"
  @@ run "%s" opam_dependencies
  @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
  @@ run "eval $(opam env)"

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let dockerfile ~repository =
  let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
  `Contents (dockerfile ~base ~repository)

let dockerfile ~src ~repository =
  let custom_dockerfile = Fpath.v "Dockerfile" in
  let* existing = file_exists ~src custom_dockerfile in
  if existing then Current.return (`File custom_dockerfile)
  else dockerfile ~repository
