module Github = Current_github
module Git = Current_git

type github = {
  repo_id : Github.Repo_id.t;
  pull_number : int option;
  branch : string option;
  commit : Github.Api.Commit.t;
}
[@@deriving ord, show]

type local = {
  repo_path : Fpath.t;
  branch : string option;
  commit : Git.Commit.t;
}
[@@deriving ord, show]

type t = Github of github | Local of local [@@deriving ord, show]

let github ~repo_id ?pull_number ?branch ~commit () =
  Github { repo_id; pull_number; branch; commit }

let local ?branch ~repo_path ~commit () = Local { repo_path; branch; commit }

let is_github t = match t with Github _ -> true | _ -> false

let is_local t = match t with Github _ -> true | _ -> false

let fetch t =
  match t with
  | Github { commit; _ } ->
      Git.fetch (Current.map Github.Api.Commit.id (Current.return commit))
  | Local { commit; _ } -> Current.return commit

let repo_id_string t =
  match t with
  | Github { repo_id = { owner; name }; _ } -> String.concat "/" [ owner; name ]
  | Local { repo_path; _ } -> Fpath.to_string repo_path

let hash t =
  match t with
  | Github { commit; _ } -> Github.Api.Commit.hash commit
  | Local { commit; _ } -> Git.Commit.hash commit

let branch t =
  match t with Github { branch; _ } -> branch | Local { branch; _ } -> branch
