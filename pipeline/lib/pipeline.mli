module Logging = Logging
module Github = Current_github
module Frontend = Frontend

module Config : sig
  type t

  val of_file : frontend_url:string -> pipeline_url:string -> Fpath.t -> t
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
  front:Frontend.config ->
  server:Conduit_lwt_unix.server ->
  sources:Source.t list ->
  string ->
  unit ->
  unit Current.or_error
