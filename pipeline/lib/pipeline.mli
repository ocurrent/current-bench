module Logging = Logging
module Github = Current_github

module Source : sig
  type t

  val github :
    token:Fpath.t ->
    webhook_secret:string ->
    slack_path:Fpath.t option ->
    repo:Github.Repo_id.t ->
    t

  val local : Fpath.t -> t

  val github_app : Github.App.t -> t
end

module Docker_config : sig
  type t

  val v : ?cpu:string -> ?numa_node:int -> shm_size:int -> unit -> t
end

val v :
  current_config:Current.Config.t ->
  docker_config:Docker_config.t ->
  server:Conduit_lwt_unix.server ->
  source:Source.t ->
  string ->
  unit ->
  unit Current.or_error
