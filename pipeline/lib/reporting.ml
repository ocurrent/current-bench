open Current.Syntax

module Github = struct
  module Github = Current_github

  let ( >>| ) x f = Current.map f x

  let github_status_of_state url = function
    | Ok _ -> Github.Api.Status.v ~url `Success ~description:"Passed"
    | Error (`Active _) -> Github.Api.Status.v ~url `Pending
    | Error (`Msg m) -> Github.Api.Status.v ~url `Failure ~description:m

  (* $server/$repo_owner/$repo_name/pull/$pull_number *)
  let make_commit_status_url ~repo_info pull_number =
    let uri_end =
      match pull_number with
      | None -> "/" ^ repo_info
      | Some number -> "/" ^ repo_info ^ "/pull/" ^ string_of_int number
    in
    Uri.of_string (Repository.frontend_url ^ uri_end)

  let report_github_status (repository : Repository.t) head state =
    let repo_info = Repository.info repository in
    let pull_number = Repository.pull_number repository in
    let status_url = make_commit_status_url ~repo_info pull_number in
    state
    >>| github_status_of_state status_url
    |> Github.Api.Commit.set_status (Current.return head) "ocaml-benchmarks"
    |> Current.ignore_value

  let post repository output =
    Current.component "github-post"
    |> let** (repository : Repository.t) = repository in
       match Repository.github_head repository with
       | Some head ->
           output |> Current.state |> report_github_status repository head
       | _ -> Current.return ()
end

module Slack = struct
  module Slack = Current_slack
  open Current.Syntax

  let read_channel_uri p =
    Util.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

  let post ~path output =
    let* output = output in
    match path with
    | Some path ->
        let channel = read_channel_uri path in
        Slack.post channel ~key:"current-bench-output" (Current.return output)
    | None -> Current.return ()
end
