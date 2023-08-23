module Db = Models.Benchmark.Db

module Get_commits = struct
  type t = string

  let id = "commit-history"

  module Key = struct
    type t = { commit : Current_git.Commit.t; repo_id : string }

    let digest { commit; repo_id } =
      Fmt.str "%s/%s" repo_id (Current_git.Commit.marshal commit)
  end

  module Value = struct
    type v = { commit : Current_git.Commit_id.t; commit_message : string }
    type t = v list

    let string_of_v { commit; commit_message } =
      Fmt.str "%S: %s\n" commit_message (Current_git.Commit_id.digest commit)

    let marshal t = String.concat "\n" (List.map string_of_v t)

    let unmarshal str =
      let lines = String.split_on_char '\n' str in
      List.map
        (fun line ->
          Scanf.sscanf line "\"%s\": %s %s %s"
            (fun commit_message repo gref hash ->
              {
                commit = Current_git.Commit_id.v ~repo ~gref ~hash;
                commit_message;
              }))
        lines

    let pp t = print_endline (marshal t)
  end

  open Lwt.Syntax

  let hash_to_parent dir t =
    let cmd =
      [|
        "git";
        "-C";
        dir;
        "rev-list";
        "--format=oneline";
        "-1";
        Fmt.str "\"%s^\"" t;
      |]
    in
    let+ line = Lwt_process.pread ("", cmd) in
    Scanf.sscanf line "%s %s@\n" (fun hash msg -> (hash, msg))

  let build conninfo job { Key.commit; repo_id } =
    let* () = Current.Job.start job ~level:Current.Level.Average in
    Current_git.with_checkout ~job commit @@ fun dir ->
    let dir = Fpath.to_string dir in
    let rec loop hash acc =
      if Db.commit_exists ~conninfo ~repo_id ~hash
      then (
        Value.pp acc;
        Lwt.return (Ok acc))
      else
        let* hash, msg = hash_to_parent dir hash in
        let parent = Current_git.Commit_id.v ~repo:dir ~hash ~gref:hash in
        loop hash ({ Value.commit = parent; commit_message = msg } :: acc)
    in
    loop (Current_git.Commit.hash commit) []

  let pp f { Key.commit; repo_id } =
    Fmt.pf f "@[<v2>git commit history %s/%a@]" repo_id Current_git.Commit.pp
      commit

  let auto_cancel = true
end

module Cache = Current_cache.Make (Get_commits)
open Current.Syntax

let get_history conninfo repo =
  let commits =
    Current.component "get-history"
    |> let> commit = Repository.src repo in
       let repo_id = Repository.info repo in
       Cache.get conninfo { Get_commits.Key.commit; repo_id }
  in
  Current.map
    (List.map (fun { Get_commits.Value.commit; commit_message } ->
         { repo with commit; commit_message = Some commit_message }))
    commits
