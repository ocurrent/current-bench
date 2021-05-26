module Logging = Logging
module Github = Current_github

module Source : sig
  type t

  val github : token:Fpath.t -> repo:Github.Repo_id.t -> t

  val local : Fpath.t -> t

  val github_app : Github.App.t -> t
end

module Config : sig
  module Docker : sig
    type t

    val make :
      ?cpuset_cpus:string -> ?numa_node:int -> shm_size:int -> unit -> t
  end

  module Slack : sig
    type t

    val make : ?path:Fpath.t -> unit -> t
  end

  type t = { docker : Docker.t; slack : Slack.t }
end

val v :
  current_config:Current.Config.t ->
  docker_config:Config.Docker.t ->
  slack_config:Config.Slack.t ->
  server:Conduit_lwt_unix.server ->
  source:Source.t ->
  string ->
  unit ->
  unit Current.or_error
