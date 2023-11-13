module Comm = Current_git.Commit
module Comm_id = Current_git.Commit_id
module Db = Models.Benchmark.Db

(** Maximum number of commits we'll return with [get_history]. *)
let runaway_limit = 20

module Get_commits = struct
  type t = string

  let id = "commit-history"

  module Key = struct
    type t = { commit : Comm.t; repo_id : string }

    let digest { commit; repo_id } =
      Fmt.str "%s/%s" repo_id (Comm.marshal commit)
  end

  module Value = struct
    type v = { hash : string; title : string; commit_message : string }
    [@@deriving yojson]

    type t = v list [@@deriving yojson]

    let marshal t = t |> to_yojson |> Yojson.Safe.to_string

    let unmarshal t =
      match Yojson.Safe.from_string t |> of_yojson with
      | Ppx_deriving_yojson_runtime.Result.Ok x -> x
      | Ppx_deriving_yojson_runtime.Result.Error msg ->
          Fmt.failwith "Unmarshalling Commit.Value.t failed with message: %s"
            msg
  end

  open Lwt.Syntax

  let hash_to_parent dir t =
    (* asks git what the commit before `t` is. git answers in the format:
       hashhashhashhashhashhash title
       rest of the
       commit message
    *)
    let cmd =
      [|
        "git";
        "-C";
        dir;
        "rev-list";
        "--no-commit-header";
        "--ignore-missing";
        "--format=%H %B";
        "-1";
        t ^ "^";
      |]
    in
    let+ lines = Lwt_process.pread ("git", cmd) in
    if lines = ""
    then None
    else
      (* In below format, `\003` is the End Of Text codepoint, and is assumed
         to never be in the commit message. *)
      Scanf.sscanf lines "%s %s@\n %s@\003" (fun hash title msg ->
          Some (hash, title, String.trim msg))

  let build conninfo job { Key.commit; repo_id } =
    let* () = Current.Job.start job ~level:Current.Level.Average in
    if not @@ Db.repo_exists ~conninfo ~repo_id
    then Lwt.return (Ok [])
    else
      Current_git.with_checkout ~job commit @@ fun dir ->
      let dir = Fpath.to_string dir in
      let rec loop i hash acc =
        if i >= runaway_limit
        then Lwt.return (Ok acc)
        else
          let* parent_opt = hash_to_parent dir hash in
          match parent_opt with
          | Some (hash, title, commit_message)
            when not @@ Db.commit_exists ~conninfo ~repo_id ~hash ->
              loop (i + 1) hash ({ Value.hash; title; commit_message } :: acc)
          | _ -> Lwt.return (Ok acc)
      in
      loop 0 (Comm.hash commit) []

  let pp f { Key.commit; repo_id } =
    Fmt.pf f "@[<v2>git commit history %s/%a@]" repo_id Comm.pp commit

  let auto_cancel = true
end

module Cache = Current_cache.Make (Get_commits)
open Current.Syntax

(** From one [Repository.t] (a repo at a specific commit), get the list of
    commits in that repo that need to be benchmarked. If that repo has never
    been benchmarked before (new addition to the service), we only bench the
    last commit. As a safety measure for now, we only bench [runaway_limit]
    commits at a maximum. *)
let get_history ~conninfo repo =
  let repo_id = Repository.info repo in
  let+ commits =
    Current.component "get-history"
    |> let> commit = Repository.src repo in
       Cache.get conninfo { Get_commits.Key.commit; repo_id }
  in
  repo
  :: List.map
       (fun { Get_commits.Value.hash; title; commit_message } ->
         let commit = Comm_id.v ~repo:repo_id ~hash ~gref:hash in
         let src =
           let+ src = repo.src in
           let repo = Comm.repo src in
           Comm.v ~repo ~id:commit
         in
         {
           repo with
           src;
           commit;
           title = Some title;
           commit_message = Some commit_message;
         })
       commits
