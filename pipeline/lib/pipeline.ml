module Github = Current_github
module Docker = Current_docker.Default
module Git = Current_git
module Docker_util = Current_util.Docker_util
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

let monitor_commit ~(config : Config.t) commit_context =
  let* commit_context = commit_context in
  let output =
    let conninfo = Uri.to_string config.db_uri in
    Postgresql_util.with_connection ~conninfo (fun db ->
        let commit = Commit_context.fetch commit_context in
        let* state = Engine.Docker_engine.build ~pool commit_context commit in
        let* output =
          Engine.Docker_engine.run ~config state commit_context db
        in
        let* () =
          Engine.Docker_engine.complete commit_context state output db
        in
        Current.return output)
  in
  let* () = Reporting.Slack.post ~path:config.slack_path output in
  let* () = Reporting.Github.post commit_context output in
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

  let monitor_repo ~config repo =
    repo
    |> collect_commits
    |> Current.list_iter (module Commit_context) (monitor_commit ~config)

  let monitor_installation ~config installation =
    installation
    |> Github.Installation.repositories
    |> Current.list_iter (module Github.Api.Repo) (monitor_repo ~config)

  let monitor_app ~config app =
    app
    |> Github.App.installations
    |> Current.list_iter
         (module Github.Installation)
         (monitor_installation ~config)
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

  let monitor_repo ~config repo_path =
    let commit_context = make_commit_context repo_path in
    monitor_commit ~config commit_context
end

let monitor ~config (source : Source.t) =
  match source with
  | Github { repo; token } ->
      let api = Github_pipeline.github_api_of_oauth_file token in
      let repo = Current.return (api, repo) in
      Github_pipeline.monitor_repo ~config repo
  | Local repo_path -> Local_pipeline.monitor_repo ~config repo_path
  | Github_app app -> Github_pipeline.monitor_app ~config app

let v ~config ~server:mode ~(source : Source.t) () =
  let pipeline () = monitor ~config source in
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
