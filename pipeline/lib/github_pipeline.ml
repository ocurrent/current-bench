module Github = Current_github
open Current.Syntax

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
  |> Current.list_iter
       (module Commit_context)
       (Base_pipeline.monitor_commit ~config)

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
