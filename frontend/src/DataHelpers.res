let getBranchName = full => {
  switch String.split_on_char('/', full) {
  | list{_scope, _repo} => "master"
  | list{_scope, _repo, branch} => branch
  | _ =>
    Js.log("Invalid branch: " ++ full)
    "master"
  }
}

let trimCommit = commit => String.length(commit) > 7 ? String.sub(commit, 0, 7) : commit
