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

let file_exists ~repository filename =
  Current.component "file-exists %S" (Fpath.to_string filename)
  |> let> commit = Repository.src repository in
     Cache.get () { File_exists.Key.commit; filename }

let base_dockerfile ~base =
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run
       "sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
        liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev \
        libpcre3-dev && opam remote add origin https://opam.ocaml.org && opam \
        update && eval $(opam env)"

let add_workdir =
  let open Dockerfile in
  copy ~src:[ "--chown=opam:opam ." ] ~dst:"bench-dir" ()
  @@ workdir "bench-dir"
  @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()

let minimal_dockerfile ~base =
  let open Dockerfile in
  base_dockerfile ~base @@ add_workdir

let docker_exec ~pool ~run_args ~repository ~dockerfile args =
  let { Repository.branch; pull_number; _ } = repository in
  let repo_info = Repository.info repository in
  let src = Repository.src repository in
  let image = Docker.build ~pool ~pull:false ~dockerfile (`Git src) in
  let commit = Repository.commit_hash repository in
  Current_util.Docker_util.pread_log ~pool ~run_args ~repo_info ?pull_number
    ?branch ~commit ~args image

let opam_install ~repository =
  let repository_name = Repository.name repository in
  (* FIXME: This should be supported by a custom Dockerfiles. *)
  if String.equal repository_name "dune" then
    "opam install ./dune-bench.opam -y --deps-only"
  else "opam install -y --deps-only ."

let with_base f ~base = Current.map (fun base -> `Contents (f ~base)) base

let discover_dependencies ~pool ~run_args ~repository ~base =
  let cmd =
    opam_install ~repository
    ^ " --dry-run | sed -n '/^Installing \\(.*\\).$/{s//\\1/g;p}'"
  in
  let args = [ "/bin/sh"; "-c"; cmd ] in
  let dockerfile = with_base minimal_dockerfile ~base in
  let+ output = docker_exec ~pool ~run_args ~repository ~dockerfile args in
  String.concat " " (String.split_on_char '\n' output)

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let dockerfile ~repository ~base ~dependencies =
  let open Dockerfile in
  let install_static_dependencies =
    if dependencies = "" then empty else run "opam install -y %s" dependencies
  in
  base_dockerfile ~base
  @@ install_static_dependencies
  @@ add_workdir
  @@ run "%s" (opam_install ~repository)

let dockerfile ~pool ~run_args ~repository =
  let base = Docker.pull ~schedule:weekly "ocaml/opam" in
  let* dependencies = discover_dependencies ~pool ~run_args ~repository ~base in
  with_base (dockerfile ~dependencies ~repository) ~base

let dockerfile ~pool ~run_args ~repository =
  let custom_dockerfile = Fpath.v "bench.Dockerfile" in
  let* existing = file_exists ~repository custom_dockerfile in
  if existing then Current.return (`File custom_dockerfile)
  else dockerfile ~pool ~run_args ~repository
