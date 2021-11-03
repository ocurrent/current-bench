open Current.Syntax
module Docker = Current_docker.Default

module Get_files = struct
  type t = unit

  let id = "get-files"

  module Key = struct
    type t = { commit : Current_git.Commit.t }

    let to_json t =
      `Assoc [ ("commit", `String (Current_git.Commit.hash t.commit)) ]

    let digest t = Yojson.Safe.to_string (to_json t)

    let pp f t = Yojson.Safe.pretty_print f (to_json t)
  end

  module Value = struct
    type t = string list

    (* convert string list to string *)
    let marshal t = String.concat "\n" t

    (* convert string to string list *)
    let unmarshal t = String.split_on_char '\n' t
  end

  open Lwt.Infix

  let build () job { Key.commit } =
    Current.Job.start job ~level:Current.Level.Average >>= fun () ->
    Current_git.with_checkout ~job commit @@ fun dir ->
    let directory = Fpath.(to_string dir) in
    Lwt_stream.to_list (Lwt_unix.files_of_directory directory) >>= fun ok ->
    Lwt.return (Ok ok)

  let pp f key = Fmt.pf f "@[<v2>git file exists %a@]" Key.pp key

  let auto_cancel = true
end

module Cache = Current_cache.Make (Get_files)

let pp_commit = Fmt.(string)

let get_all_files ~repository =
  Current.component "get-files"
  |> let> commit = Repository.src repository in
     Cache.get () { Get_files.Key.commit }

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

let docker_exec ~label ~pool ~repository ~dockerfile args =
  let info = Repository.info repository in
  let src = Repository.src repository in
  let image = Docker.build ~pool ~pull:false ~dockerfile (`Git src) in
  Current_util.Docker.pread_log ~label ~pool ~info ~args image

let opam_install ~opam_file =
  match String.compare opam_file "" with
  | 0 -> Format.sprintf "opam install -y --deps-only ."
  | _ -> Format.sprintf "opam install %s -y --deps-only" opam_file

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let base = Docker.pull ~schedule:weekly "ocaml/opam"

let with_base f = Current.map (fun base -> `Contents (f ~base)) base

let discover_dependencies ~pool ~repository ~opam_file =
  let cmd =
    opam_install ~opam_file
    ^ " --dry-run | sed -n '/^Installing \\(.*\\).$/{s//\\1/g;p}'"
  in
  let args = [ "/bin/sh"; "-c"; cmd ] in
  let dockerfile = with_base minimal_dockerfile in
  let+ output =
    docker_exec ~label:"discover-dependencies" ~pool ~repository ~dockerfile
      args
  in
  String.concat " " (String.split_on_char '\n' output)

let dockerfile ~base ~dependencies ~opam_file =
  let open Dockerfile in
  let install_static_dependencies =
    if dependencies = "" then empty else run "opam install -y %s" dependencies
  in
  base_dockerfile ~base
  @@ install_static_dependencies
  @@ add_workdir
  @@ run "%s" (opam_install ~opam_file)

let dockerfile ~pool ~repository ~opam_file =
  let* dependencies = discover_dependencies ~pool ~repository ~opam_file in
  with_base (dockerfile ~dependencies ~opam_file)

let dockerfile ~pool ~repository =
  let custom_dockerfile = Fpath.v "bench.Dockerfile" in
  let* file_list = get_all_files ~repository in
  Logs.info (fun logs ->
      logs "These are all the fetched files %s" (String.concat "\n" file_list));
  let dockerfile_exists =
    List.mem (Fpath.to_string custom_dockerfile) file_list
  in
  let r = Str.regexp "^.*-bench\\.opam$" in
  let acc = "" in
  let opam_file =
    List.fold_left
      (fun acc v -> if Str.string_match r v 0 then acc ^ " ./" ^ v else acc)
      acc file_list
  in
  if dockerfile_exists then Current.return (`File custom_dockerfile)
  else dockerfile ~pool ~repository ~opam_file
