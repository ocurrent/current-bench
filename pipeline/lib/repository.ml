type t = {
  owner : string;
  name : string;
  src : Current_git.Commit.t Current.t;
  commit : Current_git.Commit_id.t;
  commit_message : string option;
  pull_number : int option;
  pull_base : string option;
  branch : string option;
  github_head : Current_github.Api.Commit.t option;
  github_api : Current_github.Api.t option;
  title : string option;
  labels : string list;
}

let default_src ?src commit =
  match src with
  | None -> Current_git.fetch (Current.return commit)
  | Some src -> src

let v ~owner ~name ?src ~commit ?commit_message ?pull_number ?pull_base ?branch
    ?github_head ?github_api ?title ~labels () =
  {
    owner;
    name;
    commit;
    commit_message;
    pull_number;
    pull_base;
    branch;
    github_head;
    github_api;
    src = default_src ?src commit;
    title;
    labels;
  }

let owner t = t.owner
let name t = t.name
let src t = t.src
let commit t = t.commit
let commit_message t = t.commit_message
let commit_hash t = Current_git.Commit_id.hash t.commit
let pull_number t = t.pull_number
let pull_base t = t.pull_base
let title t = t.title
let labels t = t.labels
let branch t = t.branch
let github_head t = t.github_head
let github_api t = t.github_api
let id t = (t.owner, t.name)
let info t = t.owner ^ "/" ^ t.name

let to_string t =
  let pr =
    match t.pull_number with None -> "" | Some pr -> " #" ^ string_of_int pr
  in
  let br = match t.branch with None -> "" | Some br -> " " ^ br in
  let hash = Current_git.Commit_id.hash t.commit in
  let hash = String.sub hash 0 6 in
  info t ^ br ^ pr ^ " `" ^ hash ^ "`"

let to_path t =
  let pr =
    match t.pull_number with
    | None -> ""
    | Some pr -> "/pull/" ^ string_of_int pr
  in
  info t ^ pr

let frontend_url () = Sys.getenv "OCAML_BENCH_FRONTEND_URL"

(* $server/$repo_owner/$repo_name/pull/$pull_number *)
let commit_status_url { owner; name; pull_number; _ } =
  let uri_end =
    match pull_number with
    | None -> "/" ^ owner ^ "/" ^ name
    | Some number -> "/" ^ owner ^ "/" ^ name ^ "/pull/" ^ string_of_int number
  in
  Uri.of_string (frontend_url () ^ uri_end)

let compare a b =
  let cmp =
    Stdlib.compare
      (a.owner, a.name, a.branch, a.pull_number)
      (b.owner, b.name, b.branch, b.pull_number)
  in
  match cmp with
  | 0 -> Current_git.Commit_id.compare a.commit b.commit
  | _ -> cmp

let pp =
  let open Fmt.Dump in
  record
    [
      field "owner" owner Fmt.string;
      field "name" name Fmt.string;
      field "branch" branch Fmt.(option string);
      field "pull_number" pull_number Fmt.(option int);
      field "commit" commit_hash Fmt.string;
      field "labels" labels Fmt.(list string);
    ]
