open Current.Syntax
module Docker = Current_docker.Default

module Env = struct
  type t = {
    worker : string;
    image : string;
    dockerfile : [ `File of Fpath.t | `Contents of Dockerfile.t Current.t ];
  }

  let compare a b = Stdlib.compare (a.worker, a.image) (b.worker, b.image)
  let pp f t = Fmt.pf f "%s %s" t.worker t.image
  let find config repository = Config.find config (Repository.info repository)
end

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

let install_opam_dependencies ~files =
  if not (List.exists (String.ends_with ~suffix:".opam") files)
  then Dockerfile.empty
  else
    let open Dockerfile in
    copy ~src:[ "--chown=opam:opam ./*.opam" ] ~dst:"./" ()
    @@ run "opam exec -- opam pin -y -n --with-version=dev ."
    @@ run "opam exec -- opam install -y --depext-only ."
    @@ run "opam exec -- opam install -y --deps-only ."

let dockerfile ~base ~files =
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run "sudo apt-get update"
  @@ run
       "sudo apt-get install -qq -yy --no-install-recommends libffi-dev \
        liblmdb-dev m4 pkg-config libgmp-dev libssl-dev libpcre3-dev"
  @@ run "sudo mv /usr/bin/opam-2.1 /usr/bin/opam"
  @@ run "opam remote add origin https://opam.ocaml.org"
  @@ run "opam update"
  @@ run "mkdir bench-dir && chown opam:opam bench-dir"
  @@ workdir "bench-dir"
  @@ install_opam_dependencies ~files
  @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"." ()

let dockerfile ~base ~files = Dockerfile.crunch (dockerfile ~base ~files)

let dockerfiles ~config ~repository =
  let custom_dockerfile = "bench.Dockerfile" in
  let+ files = get_all_files ~repository in
  let dockerfile_exists = List.mem custom_dockerfile files in
  List.map
    (fun conf ->
      let image, dockerfile =
        if dockerfile_exists
        then (custom_dockerfile, `File (Fpath.v custom_dockerfile))
        else
          let image = conf.Config.image in
          ( image,
            `Contents
              (let+ base = Config.find_image config image in
               dockerfile ~base ~files) )
      in
      { Env.worker = conf.Config.worker; image; dockerfile })
    (Env.find config repository)
