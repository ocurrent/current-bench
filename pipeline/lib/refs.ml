module Github = Current_github

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

  let ( / ) a b = Yojson.Safe.Util.member b a

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
