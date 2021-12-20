module Logging = Logging
module Github = Current_github

module Config : sig
  type t

  val of_file : Fpath.t -> t
end

module Source : sig
  type t

  val github :
    token:Fpath.t -> webhook_secret:string -> repo:Github.Repo_id.t -> t

  val local : Fpath.t -> t

  val github_app : Github.App.t -> t
end

val v :
  config:Config.t ->
  server:Conduit_lwt_unix.server ->
  sources:Source.t list ->
  string ->
  unit ->
  unit Current.or_error
