module Git = Current_git
module Github = Current_github
module Docker = Current_docker.Default
module Logging = Logging
module Config = Config
open Current.Syntax

let ( >>| ) x f = Current.map f x

module Source = struct
  type github = { token : Fpath.t; repo : Github.Repo_id.t }

  type t = Github of github | Local of Fpath.t | Github_app of Github.App.t

  let github ~token ~repo = Github { token; repo }

  let local path = Local path

  let github_app t = Github_app t
end

module Docker_config = struct
  type t = { cpu : string option; numa_node : int option; shm_size : int }

  let v ?cpu ?numa_node ~shm_size () = { cpu; numa_node; shm_size }

  let cpuset_cpus t =
    match t.cpu with Some cpu -> [ "--cpuset-cpus"; cpu ] | None -> []

  let cpuset_mems t =
    match t.numa_node with
    | Some i -> [ "--cpuset-mems"; string_of_int i ]
    | None -> []

  let tmpfs t =
    match t.numa_node with
    | Some i ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d" t.shm_size i;
        ]
    | None ->
        [ "--tmpfs"; Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" t.shm_size ]

  let run_args t =
    [
      "--security-opt";
      "seccomp=./aslr_seccomp.json";
      "--mount";
      "type=volume,src=current-bench-data,dst=/home/opam/bench-dir/current-bench-data";
    ]
    @ tmpfs t
    @ cpuset_cpus t
    @ cpuset_mems t
end

let pool = Current.Pool.create ~label:"docker" 1

let log_commit_info job commit_context =
  let repo_owner, repo_name = Repository.id commit_context in
  let branch = Repository.branch commit_context in
  let commit = Repository.commit_hash commit_context in
  Current.Job.log job "repo=%S/%S branch=(%a) commit=%S" repo_owner repo_name
    Fmt.Dump.(option string)
    branch commit

let string_of_output output =
  String.concat "\n" (List.map Yojson.Safe.pretty_to_string output)

let build_commit ~db repository =
  Current.component "build"
  |> let** repository = repository in
     let img = Engine.Docker_engine.build ~pool ~repository in
     let current_job_id_opt = Current_util.get_job_id img in
     let* job_id_opt = current_job_id_opt in
     match job_id_opt with
     | None ->
         Fmt.epr "build job id not ready@.";
         Current.pair img current_job_id_opt
     | Some build_job_id ->
         let () =
           match Current.Job.lookup_running build_job_id with
           | None -> Fmt.epr "build job %s is not running@." build_job_id
           | Some job -> log_commit_info job repository
         in
         Storage.record_build_start ~repository ~build_job_id db;
         Current.pair img current_job_id_opt

let run_commit ~db ~(repository : Repository.t Current.t) ~build_job_id
    ~run_args img =
  Current.component "build"
  |> let** repository = repository in
     let info = Repository.show repository in
     let output = Engine.Docker_engine.run ~info ~pool ~run_args img in
     let* run_job_id_opt = Current_util.get_job_id output in
     match run_job_id_opt with
     | None ->
         Fmt.epr "run job id not ready@.";
         Current.return None
     | Some run_job_id ->
         let repo_id_string = Repository.info repository in
         let* output = Current.map Json_util.parse_many output in
         Storage.record_run_finish ~repo_id_string ~build_job_id ~run_job_id
           ~output db;
         Current.return (Some output)

let monitor_commit ~db ~run_args repository =
  let build_state = build_commit ~db repository in
  let img = Current.map fst build_state in
  let* build_job_id_opt = Current.map snd build_state in
  let* output =
    match build_job_id_opt with
    | None ->
        Fmt.epr "build job id not ready@.";
        Current.return None
    | Some build_job_id ->
        run_commit ~db ~repository ~build_job_id ~run_args img
  in
  match output with
  | None -> Current.return ()
  | Some output ->
      let* () =
        let* repository = repository in
        Reporting.Slack.post
          ~path:(Repository.slack_path repository)
          (Current.return (string_of_output output))
      in
      let* () = Reporting.Github.post repository (Current.return output) in
      Current.return ()

module Github_pipeline = struct
  let github_api_of_oauth_file token =
    token |> Util.read_fpath |> String.trim |> Current_github.Api.of_oauth

  let collect_commits repo =
    let* refs =
      Current.component "get-github-refs"
      |> let> api, repo_id = repo in
         Github.Api.refs api repo_id
    in
    let all_refs = Github.Api.all_refs refs in
    let+ _, repo_id = repo in
    let default_ref = Github.Api.default_ref refs in
    let repository = Repository.v ~name:repo_id.name ~owner:repo_id.owner in
    Github.Api.Ref_map.fold
      (fun key head acc ->
        let commit = Github.Api.Commit.id head in
        let repository = repository ~commit ~github_head:head in
        match key with
        | `PR pull_number -> repository ~pull_number () :: acc
        | `Ref ref when String.equal ref default_ref ->
            repository ~branch:default_ref () :: acc
        | `Ref _ -> acc)
      all_refs []

  let monitor_repo ~db ~run_args repo =
    repo
    |> collect_commits
    |> Current.list_iter (module Repository) (monitor_commit ~db ~run_args)

  let monitor_installation ~db ~run_args installation =
    installation
    |> Github.Installation.repositories
    |> Current.list_iter (module Github.Api.Repo) (monitor_repo ~db ~run_args)

  let monitor_app ~db ~run_args app =
    app
    |> Github.App.installations
    |> Current.list_iter
         (module Github.Installation)
         (monitor_installation ~db ~run_args)
end

module Local_pipeline = struct
  let branch_of_head head =
    match head with
    | `Commit _ -> None
    | `Ref git_ref -> (
        match String.split_on_char '/' git_ref with
        | [ _; _; branch ] -> Some branch
        | _ -> None)

  let make_commit_context repo_path =
    let local = Git.Local.v repo_path in
    let src = Git.Local.head_commit local in
    let+ head = Git.Local.head local and+ commit = src >>| Git.Commit.id in
    let branch = branch_of_head head in
    Repository.v ?branch ~src ~commit ~name:"local" ~owner:"local" ()

  let monitor_repo ~db ~run_args repo_path =
    let commit_context = make_commit_context repo_path in
    monitor_commit ~db ~run_args commit_context
end

let monitor ~db (source : Source.t) ~run_args =
  match source with
  | Github { repo; token } ->
      let api = Github_pipeline.github_api_of_oauth_file token in
      let repo = Current.return (api, repo) in
      Github_pipeline.monitor_repo ~db ~run_args repo
  | Local repo_path -> Local_pipeline.monitor_repo ~db ~run_args repo_path
  | Github_app app -> Github_pipeline.monitor_app ~db ~run_args app

let v ~current_config ~docker_config ~server:mode ~(source : Source.t) conninfo
    () =
  let db = new Postgresql.connection ~conninfo () in
  let run_args = Docker_config.run_args docker_config in
  let pipeline () = monitor ~db ~run_args source in
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
