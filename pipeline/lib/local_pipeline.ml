module Git = Current_git
open Current.Syntax

let branch_of_head head =
  match head with
  | `Commit _ -> None
  | `Ref git_ref -> (
      match String.split_on_char '/' git_ref with
      | [ _; _; branch ] -> Some branch
      | _ -> None)

let make_commit_context repo_path =
  let git = Git.Local.v repo_path in
  let* head = Git.Local.head git in
  let* commit = Git.Local.head_commit git in
  let branch = branch_of_head head in
  let commit_context = Commit_context.local ?branch ~repo_path ~commit () in
  Current.return commit_context

let monitor_repo ~config repo_path =
  let commit_context = make_commit_context repo_path in
  Base_pipeline.monitor_commit ~config commit_context
