type t = {
  owner : string;
  name : string;
  src : Current_git.Commit.t Current.t;
  pull_number : int option;
  branch : string option;
  slack_path : Fpath.t option;
}

let owner t = t.owner

let name t = t.name

let src t = t.src

let pull_number t = t.pull_number

let branch t = t.branch

let slack_path t = t.slack_path

let id t = (t.owner, t.name)

let info t = t.owner ^ "/" ^ t.name

let commit_hash t = Current.map Current_git.Commit.hash t.src

let frontend_url = Sys.getenv "OCAML_BENCH_FRONTEND_URL"

(* $server/$repo_owner/$repo_name/pull/$pull_number *)
let commit_status_url { owner; name; pull_number; _ } =
  let uri_end =
    match pull_number with
    | None -> "/" ^ owner ^ "/" ^ name
    | Some number -> "/" ^ owner ^ "/" ^ name ^ "/pull/" ^ string_of_int number
  in
  Uri.of_string (frontend_url ^ uri_end)
