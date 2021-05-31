module Logging = Logging
module Github = Current_github

module Source : sig
  type t

  val github : token:Fpath.t -> repo:Github.Repo_id.t -> t

  val local : Fpath.t -> t

  val github_app : Github.App.t -> t
end

module Config : sig
  type t

  val make :
    current:Current.Config.t ->
    ?docker_cpuset_cpus:string ->
    ?docker_numa_node:int ->
    docker_shm_size:int ->
    ?slack_path:Fpath.t ->
    db_uri:Uri.t ->
    unit ->
    t
end

val v :
  config:Config.t ->
  server:Conduit_lwt_unix.server ->
  source:Source.t ->
  unit ->
  unit Current.or_error
