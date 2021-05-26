module Github = Current_github
module Git = Current_git
open Current.Syntax

let pool = Current.Pool.create ~label:"docker" 1

let github_api_of_oauth_file token =
  token |> Util.read_fpath |> String.trim |> Current_github.Api.of_oauth

let conninfo () = assert false

let execute ~(config : Config.t) commit_context =
  Postgresql_util.with_connection ~conninfo:(conninfo ()) (fun db ->
      let commit = Commit_context.fetch commit_context in
      let* state = Engine.Docker_engine.build ~pool commit_context commit in
      let* output =
        Engine.Docker_engine.run ~config:config.docker state commit_context db
      in
      let* () = Engine.Docker_engine.complete commit_context state output db in
      Current.return output)

let monitor_commit ~(config : Config.t) commit_context =
  let* commit_context = commit_context in
  let output = execute ~config commit_context in
  let* () = Slack_reporting.post ~config:config.slack output in
  let* () = Github_reporting.post commit_context output in
  Current.return ()

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
