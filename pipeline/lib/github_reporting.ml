module Github = Current_github

let ( >>| ) x f = Current.map f x

let frontend_url =
  try Sys.getenv "OCAML_BENCH_FRONTEND_URL"
  with Not_found -> "http://localhost:8080"

let github_status_of_state url = function
  | Ok _ -> Github.Api.Status.v ~url `Success ~description:"Passed"
  | Error (`Active _) -> Github.Api.Status.v ~url `Pending
  | Error (`Msg m) -> Github.Api.Status.v ~url `Failure ~description:m

(* $server/$repo_owner/$repo_name/pull/$pull_number *)
let make_commit_status_url ~repo_id:{ Github.Repo_id.owner; name } pull_number =
  let uri_end =
    match pull_number with
    | None -> "/" ^ owner ^ "/" ^ name
    | Some number -> "/" ^ owner ^ "/" ^ name ^ "/pull/" ^ string_of_int number
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

let post (commit_context : Commit_context.t) output =
  match commit_context with
  | Github github_context ->
      output |> Current.state |> report_github_status github_context
  | _ -> Current.return ()
