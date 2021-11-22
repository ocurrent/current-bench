module Git = Current_git
module Github = Current_github

let src = Logs.Src.create "current.git" ~doc:"OCurrent git plugin"

module Log = (val Logs.src_log src : Logs.LOG)

let ( / ) a b = Yojson.Safe.Util.member b a

module Ref = struct
  type t = [ `Ref of string | `PR of int ] [@@deriving to_yojson]

  let compare = Stdlib.compare

  let pp f = function `Ref r -> Fmt.string f r | `PR pr -> Fmt.pf f "PR %d" pr

  let to_git = function
    | `Ref head -> head
    | `PR id -> Fmt.str "refs/pull/%d/head" id
end

module Commit_id = struct
  type t = {
    owner : string;
    repo : string;
    id : Ref.t;
    hash : string;
    committed_date : string;
    title : string option;
  }
  [@@deriving to_yojson]

  let to_git { owner; repo; id; hash; title = _; committed_date = _ } =
    let repo = Fmt.str "https://github.com/%s/%s.git" owner repo in
    let gref = Ref.to_git id in
    Current_git.Commit_id.v ~repo ~gref ~hash

  let owner_name { owner; repo; _ } = Fmt.str "%s/%s" owner repo

  let uri t =
    Uri.make ~scheme:"https" ~host:"github.com"
      ~path:(Printf.sprintf "/%s/commit/%s/%s" t.owner t.repo t.hash)
      ()

  let pp_id = Ref.pp

  let compare { owner; repo; id; hash; title = _; committed_date = _ } b =
    match compare hash b.hash with
    | 0 -> (
        match Ref.compare id b.id with
        | 0 -> compare (owner, repo) (b.owner, b.repo)
        | x -> x)
    | x -> x

  let pp f { owner; repo; id; hash; title = _; committed_date } =
    Fmt.pf f "%s/%s@ %a@ %s@ %s" owner repo pp_id id
      (Astring.String.with_range ~len:8 hash)
      committed_date

  let digest t = Yojson.Safe.to_string (to_yojson t)
end

module Refs = Github.Api.Monitor (struct
  type result = string option Github.Api.Ref_map.t

  let name = "refs"

  let query =
    {|
    repository(owner: $owner, name: $name) {
      pullRequests(first: 100, states:[OPEN]) {
        totalCount
        edges {
          node {
            number
            title
          }
        }
      }
    }
  |}

  let parse_pr json =
    let open Yojson.Safe.Util in
    let node = json / "node" in
    let pr = node / "number" |> to_int in
    let title = Some (node / "title" |> to_string) in
    (`PR pr, title)

  let of_yojson _ _ data =
    let open Yojson.Safe.Util in
    let repo = data / "repository" in
    let prs = repo / "pullRequests" / "edges" |> to_list |> List.map parse_pr in
    let add xs map =
      List.fold_left
        (fun acc (key, title) -> Github.Api.Ref_map.add key title acc)
        map xs
    in
    Github.Api.Ref_map.empty |> add prs
end)

let refs t repo = Refs.get t repo
