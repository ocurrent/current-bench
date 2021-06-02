module Github := Current_github
module Git := Current_git

type github = {
  repo_id : Github.Repo_id.t;
  pull_number : int option;
  branch : string option;
  commit : Github.Api.Commit.t;
}

type local = {
  repo_path : Fpath.t;
  branch : string option;
  commit : Git.Commit.t;
}

type t = Github of github | Local of local

val compare : t -> t -> int

val pp : Format.formatter -> t -> unit

val show : t -> string

val github :
  repo_id:Github.Repo_id.t ->
  ?pull_number:int ->
  ?branch:string ->
  commit:Github.Api.Commit.t ->
  unit ->
  t

val local :
  ?branch:string -> repo_path:Fpath.t -> commit:Git.Commit.t -> unit -> t

val is_github : t -> bool

val is_local : t -> bool

val fetch : t -> Git.Commit.t Current.t

val repo_id_string : t -> string

val hash : t -> string
