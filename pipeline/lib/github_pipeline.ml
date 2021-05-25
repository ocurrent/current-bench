module Github = Current_github
module Git = Current_git
module Slack = Current_slack
open Current.Syntax

let pool = Current.Pool.create ~label:"docker" 1

let github_api_of_oauth_file token =
  token |> Util.read_fpath |> String.trim |> Current_github.Api.of_oauth

let read_channel_uri p =
  Util.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

let post_to_slack path run_output =
  let channel = read_channel_uri path in
  Slack.post channel ~key:"current-bench-output" (Current.return run_output)

module Github_reporting = struct
  let ( >>| ) x f = Current.map f x

  let frontend_url =
    try Sys.getenv "OCAML_BENCH_FRONTEND_URL"
    with Not_found -> "http://localhost:8080"

  let github_status_of_state url = function
    | Ok _ -> Github.Api.Status.v ~url `Success ~description:"Passed"
    | Error (`Active _) -> Github.Api.Status.v ~url `Pending
    | Error (`Msg m) -> Github.Api.Status.v ~url `Failure ~description:m

  (* $server/$repo_owner/$repo_name/pull/$pull_number *)
  let make_commit_status_url ~repo_id:{ Github.Repo_id.owner; name } pull_number
      =
    let uri_end =
      match pull_number with
      | None -> "/" ^ owner ^ "/" ^ name
      | Some number ->
          "/" ^ owner ^ "/" ^ name ^ "/pull/" ^ string_of_int number
    in
    Uri.of_string (frontend_url ^ uri_end)

  let report_github_status (commit_context : Commit_context.github) state =
    let repo_id = commit_context.repo_id in
    let pull_number = commit_context.pull_number in
    let commit = commit_context.commit in
    let status_url = make_commit_status_url ~repo_id pull_number in
    state
    >>| github_status_of_state status_url
    |> Github.Api.Commit.set_status (Current.return commit) "ocaml-benchmarks"
    |> Current.ignore_value
end

let conninfo () = assert false

let monitor_commit ~(config : Config.t) commit_context =
  let* commit_context = commit_context in
  Postgresql_util.with_connection ~conninfo:(conninfo ()) (fun db ->
      let current =
        let commit = Commit_context.fetch commit_context in
        let* state = Engine.Docker_engine.build ~pool commit_context commit in
        let* output =
          Engine.Docker_engine.run ~config:config.docker state commit_context db
        in
        let* () =
          Engine.Docker_engine.complete commit_context state output db
        in
        match config.slack.path with
        | Some path ->
            post_to_slack path (Engine.Docker_engine.string_of_output output)
        | None -> Current.return ()
      in
      match commit_context with
      | Github github_context ->
          current
          |> Current.state
          |> Github_reporting.report_github_status github_context
      | _ -> Current.return ())

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
