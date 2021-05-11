open Current.Syntax
module Git = Current_git
module Github = Current_github
module Docker = Current_docker.Default
module Docker_util = Current_util.Docker_util
module Slack = Current_slack
module Logging = Logging
module Benchmark = Models.Benchmark

let ( >>| ) x f = Current.map f x

module Source = struct
  type github = {
    token : Fpath.t;
    slack_path : Fpath.t option;
    repo : Github.Repo_id.t;
  }

  type t = Github of github | Local of Fpath.t | Github_app of Github.App.t

  let github ~token ~slack_path ~repo = Github { token; slack_path; repo }

  let local path = Local path

  let github_app t = Github_app t
end

module Docker_config = struct
  type t = { cpu : int option; numa_node : int option; shm_size : int }

  let v ?cpu ?numa_node ~shm_size () = { cpu; numa_node; shm_size }
end

let pool = Current.Pool.create ~label:"docker" 1

let read_channel_uri p =
  Util.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

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
        liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev"
  @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"bench-dir" ()
  @@ workdir "bench-dir"
  @@ run "opam remote add origin https://opam.ocaml.org"
  @@ run "%s" opam_dependencies
  @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
  @@ run "eval $(opam env)"

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 1) ()

let frontend_url =
  try Sys.getenv "OCAML_BENCH_FRONTEND_URL"
  with Not_found -> "http://localhost:8080"

(* $server/$repo_owner/$repo_name/pull/$pull_number *)
let make_commit_status_url ~repo_id:{ Github.Repo_id.owner; name } pull_number =
  let uri_end =
    match pull_number with
    | None -> "/" ^ owner ^ "/" ^ name
    | Some number -> "/" ^ owner ^ "/" ^ name ^ "/pull/" ^ string_of_int number
  in
  Uri.of_string (frontend_url ^ uri_end)

let github_status_of_state url = function
  | Ok _ -> Github.Api.Status.v ~url `Success ~description:"Passed"
  | Error (`Active _) -> Github.Api.Status.v ~url `Pending
  | Error (`Msg m) -> Github.Api.Status.v ~url `Failure ~description:m

module Lifecycle = struct
  let build ~repo_id ~pull_number ~branch ~dockerfile ~head db =
    let src =
      match head with
      | `Github api_commit ->
          Git.fetch
            (Current.map Github.Api.Commit.id (Current.return api_commit))
      | `Local commit -> commit
    in
    let* commit =
      match head with
      | `Github api_commit -> Current.return (Github.Api.Commit.hash api_commit)
      | `Local commit -> commit >>| Git.Commit.hash
    in
    let current_image = Docker.build ~pool ~pull:false ~dockerfile (`Git src) in
    let* build_job_id = Current_util.get_job_id current_image in
    (* FIXME: compute in db *)
    let run_at = Ptime_clock.now () in
    match build_job_id with
    | Some build_job_id ->
        Storage.record_build_start ~run_at ~repo_id ~pull_number ~branch ~commit
          ~build_job_id db;
        Current.map (fun image -> (build_job_id, image)) current_image
    | None -> failwith "No build job id"

  let run ~tmpfs ~docker_cpuset_cpus ~docker_cpuset_mems ~repo_id ~head db
      image_build =
    let run_args =
      [ "--security-opt"; "seccomp=./aslr_seccomp.json" ]
      @ tmpfs
      @ docker_cpuset_cpus
      @ docker_cpuset_mems
    in
    let* commit =
      match head with
      | `Github api_commit -> Current.return (Github.Api.Commit.hash api_commit)
      | `Local commit -> commit >>| Git.Commit.hash
    in
    let* build_job_id, _ = image_build in
    let current_image = Current.map snd image_build in
    let current_output =
      Docker_util.pread_log ~run_args current_image ~repo_info:"TODO" ~commit
        ~args:
          [
            "/usr/bin/setarch"; "x86_64"; "--addr-no-randomize"; "make"; "bench";
          ]
    in
    let* run_job_id = Current_util.get_job_id current_output
    and* output = current_output in
    match run_job_id with
    | Some run_job_id ->
        Storage.record_run_start ~repo_id ~build_job_id ~run_job_id db;
        Logs.debug (fun log -> log "Benchmark output:\n%s" output);
        let json_list = Json_util.parse_many output in
        Current.return (build_job_id, json_list)
    | _ -> failwith "No run job id"

  let finish ~repo_id ~build_job_id output db =
    Storage.record_run_finish ~repo_id ~build_job_id ~output db

  let post_to_slack path _run_output =
    let channel = read_channel_uri path in
    (* FIXME *)
    Slack.post channel ~key:"current-bench-output" (Current.return "run_output")

  let report_github_status ~repo_id ~pull_number ~head state =
    let status_url = make_commit_status_url ~repo_id pull_number in
    state
    >>| github_status_of_state status_url
    |> Github.Api.Commit.set_status (Current.return head) "ocaml-benchmarks"
    |> Current.ignore_value
end

let pipeline ~slack_path ~conninfo ?branch ?pull_number ~dockerfile ~tmpfs
    ~docker_cpuset_cpus ~docker_cpuset_mems ~head
    ?(repo_id = { Github.Repo_id.owner = "local"; name = "local" }) () =
  let db = new Postgresql.connection ~conninfo () in

  let current =
    let image_build =
      Lifecycle.build ~repo_id ~pull_number ~branch ~dockerfile ~head db
    in

    let* build_job_id, run_output =
      Lifecycle.run ~tmpfs ~docker_cpuset_cpus ~docker_cpuset_mems ~repo_id
        ~head db image_build
    in

    Lifecycle.finish ~repo_id ~build_job_id run_output db;

    match slack_path with
    | Some path -> Lifecycle.post_to_slack path (Current.return run_output)
    | None -> Current.return ()
  in

  db#finish;

  match head with
  | `Local _ -> Current.return ()
  | `Github head ->
      current
      |> Current.state
      |> Lifecycle.report_github_status ~repo_id ~pull_number ~head

let process_pipeline ~(docker_config : Docker_config.t) ~conninfo
    ~(source : Source.t) () =
  let docker_cpuset_cpus =
    match docker_config.cpu with
    | Some i -> [ "--cpuset-cpus"; string_of_int i ]
    | None -> []
  in
  let docker_cpuset_mems =
    match docker_config.numa_node with
    | Some i -> [ "--cpuset-mems"; string_of_int i ]
    | None -> []
  in
  let tmpfs =
    match docker_config.numa_node with
    | Some i ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d"
            docker_config.shm_size i;
        ]
    | None ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" docker_config.shm_size;
        ]
  in
  let pipeline =
    pipeline ~conninfo ~tmpfs ~docker_cpuset_cpus ~docker_cpuset_mems
  in
  match source with
  | Github { repo = repo_id; slack_path; token } ->
      let dockerfile =
        let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
        `Contents (dockerfile ~base ~repository:repo_id.name)
      in
      let pipeline = pipeline ~slack_path ~dockerfile ~repo_id in
      let* refs =
        let api =
          token |> Util.read_fpath |> String.trim |> Current_github.Api.of_oauth
        in
        let repo = Current.return (api, repo_id) in
        Current.component "Get PRs"
        |> let> api, repo = repo in
           Github.Api.refs api repo
      in
      let default_branch = Github.Api.default_ref refs in
      let default_branch_name = Util.get_branch_name default_branch in
      let ref_map = Github.Api.all_refs refs in
      Github.Api.Ref_map.fold
        (fun key head _ ->
          let head = `Github head in
          match key with
          | `Ref branch ->
              if branch = default_branch then
                pipeline ~head ~branch:default_branch_name ()
              else Current.return ()
          | `PR pull_number -> pipeline ~head ~pull_number ()
          (* Skip all branches other than master, and check PRs *))
        ref_map (Current.return ())
  | Local path ->
      let dockerfile =
        let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
        `Contents (dockerfile ~base ~repository:"local")
      in
      let local = Git.Local.v path in
      let* head = Git.Local.head local in
      let head_commit = `Local (Git.Local.head_commit local) in
      let branch =
        match head with
        | `Commit _ -> None
        | `Ref git_ref -> (
            match String.split_on_char '/' git_ref with
            | [ _; _; branch ] -> Some branch
            | _ ->
                Logs.warn (fun log ->
                    log "Could not extract branch name from: %s" git_ref);
                None)
      in
      pipeline ?branch ~dockerfile ~head:head_commit ~slack_path:None ()
  | Github_app app ->
      Github.App.installations app
      |> Current.list_iter (module Github.Installation) @@ fun installation ->
         let repos = Github.Installation.repositories installation in
         repos
         |> Current.list_iter ~collapse_key:"repo" (module Github.Api.Repo)
            @@ fun repo ->
            let* refs =
              Current.component "Get PRS"
              |> let> api, repo = repo in
                 Github.Api.refs api repo
            in
            let default_branch = Github.Api.default_ref refs in
            let default_branch_name = Util.get_branch_name default_branch in
            let* _, repo = repo in
            let dockerfile =
              let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
              `Contents (dockerfile ~base ~repository:repo.name)
            in
            let pipeline =
              pipeline ~dockerfile ~slack_path:None
                ~repo_id:{ Github.Repo_id.owner = repo.owner; name = repo.name }
            in
            let ref_map = Github.Api.all_refs refs in

            Github.Api.Ref_map.fold
              (fun key head _ ->
                let head = `Github head in
                match key with
                | `Ref branch ->
                    if branch = default_branch then
                      pipeline ~head ~branch:default_branch_name ()
                    else Current.return ()
                | `PR pull_number -> pipeline ~head ~pull_number ()
                (* Skip all branches other than master, and check PRs *))
              ref_map (Current.return ())

let v ~current_config ~docker_config ~server:mode ~(source : Source.t) conninfo
    () =
  Db_util.check_connection ~conninfo;
  let pipeline = process_pipeline ~docker_config ~conninfo ~source in
  let engine = Current.Engine.create ~config:current_config pipeline in
  let routes =
    Routes.((s "webhooks" / s "github" /? nil) @--> Github.webhook)
    :: Current_web.routes engine
  in
  let site =
    Current_web.Site.(v ~has_role:allow_all) ~name:"Benchmarks" routes
  in
  Logging.run
    (Lwt.choose [ Current.Engine.thread engine; Current_web.run ~mode site ])
