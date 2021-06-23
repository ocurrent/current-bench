module Github = Current_github
module Docker = Current_docker.Default
module Git = Current_git
module Logging = Logging
module Benchmark = Models.Benchmark
module Config = Config
open Current.Syntax

module Source = struct
  type github = { token : Fpath.t; repo : Github.Repo_id.t }

  type t = Github of github | Local of Fpath.t | Github_app of Github.App.t

  let github ~token ~repo = Github { token; repo }

  let local path = Local path

  let github_app t = Github_app t
end

let pool = Current.Pool.create ~label:"docker" 1

let log_commit_info job commit_context =
  let repo = Commit_context.repo_id_string commit_context in
  let branch = Commit_context.branch commit_context in
  let commit = Commit_context.hash commit_context in
  Current.Job.log job "repo=%S branch=(%a) commit=%S" repo
    Fmt.Dump.(option string)
    branch commit

let string_of_output output =
  String.concat "\n" (List.map Yojson.Safe.pretty_to_string output)

let build_commit ~db commit_context =
  Current.component "build"
  |> let** commit_context = commit_context in
     let commit = Commit_context.fetch commit_context in
     let img = Engine.Docker_engine.build ~pool commit_context commit in
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
           | Some job -> log_commit_info job commit_context
         in
         let repo_id_string = Commit_context.repo_id_string commit_context in
         let branch = Commit_context.branch commit_context in
         let pull_number = Commit_context.pull_number commit_context in
         let commit = Commit_context.hash commit_context in
         Storage.record_build_start ~repo_id:repo_id_string ~pull_number ~commit
           ~branch ~build_job_id db;
         Current.pair img current_job_id_opt

let run_commit ~db ~config ~commit_context ~build_job_id img =
  let info = Commit_context.show commit_context in
  let output = Engine.Docker_engine.run ~info ~pool ~config img in
  let* run_job_id_opt = Current_util.get_job_id output in
  match run_job_id_opt with
  | None ->
      Fmt.epr "run job id not ready@.";
      Current.return None
  | Some run_job_id ->
      let repo_id_string = Commit_context.repo_id_string commit_context in
      let* output = Current.map Json_util.parse_many output in
      Storage.record_run_finish ~repo_id_string ~build_job_id ~run_job_id
        ~output db;
      Current.return (Some output)

let monitor_commit ~db ~(config : Config.t) current_commit_context =
  Current.component "monitor_commit"
  |> let** commit_context = current_commit_context in
     Logs.debug (fun log -> log "monitor_commit");

     let build_state = build_commit ~db current_commit_context in
     let img = Current.map fst build_state in
     let* build_job_id_opt = Current.map snd build_state in

     let* output =
       match build_job_id_opt with
       | None ->
           Fmt.epr "build job id not ready@.";
           Current.return None
       | Some build_job_id ->
           run_commit ~db ~config ~commit_context ~build_job_id img
     in

     match output with
     | None -> Current.return ()
     | Some output ->
         let* () =
           Reporting.Slack.post ~path:config.slack_path
             (Current.return (string_of_output output))
         in
         let* () =
           Reporting.Github.post current_commit_context (Current.return output)
         in
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
    Github.Api.Ref_map.fold
      (fun ref commit acc ->
        match ref with
        | `PR pull_number ->
            Commit_context.github ~commit ~repo_id ~pull_number () :: acc
        | `Ref ref when String.equal ref default_ref ->
            let branch = Util.branch_name_of_ref default_ref in
            Commit_context.github ~commit ~repo_id ~branch () :: acc
        | `Ref _ -> acc)
      all_refs []

  let monitor_repo ~db ~config repo =
    repo
    |> collect_commits
    |> Current.list_iter (module Commit_context) (monitor_commit ~db ~config)

  let monitor_installation ~db ~config installation =
    installation
    |> Github.Installation.repositories
    |> Current.list_iter (module Github.Api.Repo) (monitor_repo ~db ~config)

  let monitor_app ~db ~config app =
    app
    |> Github.App.installations
    |> Current.list_iter
         (module Github.Installation)
         (monitor_installation ~db ~config)
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
    let git = Git.Local.v repo_path in
    let* head = Git.Local.head git in
    let* commit = Git.Local.head_commit git in
    let branch = branch_of_head head in
    let commit_context = Commit_context.local ?branch ~repo_path ~commit () in
    Current.return commit_context

  let monitor_repo ~db ~config repo_path =
    let commit_context = make_commit_context repo_path in
    monitor_commit ~db ~config commit_context
end

let monitor ~db ~config (source : Source.t) =
  match source with
  | Github { repo; token } ->
      let api = Github_pipeline.github_api_of_oauth_file token in
      let repo = Current.return (api, repo) in
      Github_pipeline.monitor_repo ~db ~config repo
  | Local repo_path -> Local_pipeline.monitor_repo ~db ~config repo_path
  | Github_app app -> Github_pipeline.monitor_app ~db ~config app

let v ~(config : Config.t) ~server:mode ~(source : Source.t) () =
  let db =
    let conninfo = Uri.to_string config.db_uri in
    new Postgresql.connection ~conninfo ()
  in

  let pipeline () = monitor ~db ~config source in
  let engine = Current.Engine.create ~config:config.current pipeline in
  let routes =
    Routes.((s "webhooks" / s "github" /? nil) @--> Github.webhook)
    :: Current_web.routes engine
  in
  let site =
    Current_web.Site.(v ~has_role:allow_all) ~name:"Benchmarks" routes
  in
  Logging.run
    (Lwt.choose [ Current.Engine.thread engine; Current_web.run ~mode site ])
