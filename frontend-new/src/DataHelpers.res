let getBranchName = full => {
  switch String.split_on_char('/', full) {
  | list{_scope, _repo} => "master"
  | list{_scope, _repo, branch} => branch
  | _ =>
    Js.log("Invalid branch: " ++ full)
    "master"
  }
}
