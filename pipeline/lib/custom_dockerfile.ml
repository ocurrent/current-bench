open Current.Syntax
module Docker = Current_docker.Default

module Env = struct
  type t = {
    worker : string;
    image : string;
    dockerfile : [ `File of Fpath.t | `Contents of Dockerfile.t Current.t ];
    clock : string;
    config : Config.repo;
  }

  let compare a b =
    Stdlib.compare (a.worker, a.image, a.clock) (b.worker, b.image, b.clock)

  let pp f t = Fmt.pf f "%s %s" t.config.worker t.config.image

  let find config repository =
    Current.list_seq
    @@ List.map (fun conf ->
           let+ clock = Config.get_clock config conf in
           (clock, conf))
    @@ Config.find config repository
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

let get_all_files ~cond ~repository =
  Current.component "run-benchmarks?"
  |> let** ok = cond in
     if ok then get_all_files ~repository else Current.return []

let install_opam_dependencies ~files =
  let opam_files = List.filter (String.ends_with ~suffix:".opam") files in
  let open Dockerfile in
  match opam_files with
  | [] -> empty
  | _ ->
      let targets =
        match
          List.filter (String.ends_with ~suffix:"-bench.opam") opam_files
        with
        | [] -> "."
        | bench_opam ->
            String.concat " "
              (List.map (fun filename -> "./" ^ filename) bench_opam)
      in
      copy ~chown:"opam:opam" ~src:[ "./*.opam" ] ~dst:"./" ()
      @@ run "opam exec -- opam pin -y -n --with-version=dev ."
      @@ run "opam exec -- opam install -y --depext-only %s" targets
      @@ run "opam exec -- opam install -y --deps-only --with-test %s" targets

let dockerfile ~base ~files ~bench_repo =
  let open Dockerfile in
  let extract_dir repo_url =
    repo_url |> String.split_on_char '/' |> List.rev |> List.hd
  in
  let bench_dir = bench_repo |> Option.map extract_dir in
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
  @@ copy ~chown:"opam:opam" ~src:[ "." ] ~dst:"." ()
  @@ (match (bench_repo, bench_dir) with
     | Some repo, Some dir -> run "git clone %s %s" repo dir
     | _ -> comment "No bench repo to clone")
  @@
  match bench_dir with
  | Some dir -> workdir "%s" dir
  | _ -> comment "No extra bench repo"

let dockerfile ~base ~files ~bench_repo =
  Dockerfile.crunch (dockerfile ~base ~files ~bench_repo)

let dockerfiles ~config ~repository =
  let default_file = "bench.Dockerfile" in
  let envs = Env.find config repository in
  let not_empty = Current.map (fun envs -> envs <> []) envs in
  let+ files = get_all_files ~cond:not_empty ~repository and+ envs = envs in
  let default_file_exists = List.mem default_file files in
  List.map
    (fun (clock, (conf : Config.repo)) ->
      let image, dockerfile =
        match conf.dockerfile with
        | Some custom_dockerfile ->
            (custom_dockerfile, `File (Fpath.v custom_dockerfile))
        | None when default_file_exists ->
            (default_file, `File (Fpath.v default_file))
        | None ->
            let image = conf.image in
            let docker =
              `Contents
                (let+ base = Config.find_image config image in
                 dockerfile ~base ~files ~bench_repo:conf.bench_repo)
            in
            (image, docker)
      in
      { Env.worker = conf.worker; image; dockerfile; clock; config = conf })
    envs
