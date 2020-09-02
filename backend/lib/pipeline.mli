module Logging = Logging

type token = { token_file : string; token_api_file : Current_github.Api.t }

val v :
  config:Current.Config.t ->
  server:Conduit_lwt_unix.server ->
  token:token ->
  repo:Current_github.Repo_id.t ->
  ?slack_path:Fpath.t ->
  ?docker_cpu:int ->
  ?docker_numa_node:int ->
  docker_shm_size:int ->
  string ->
  unit ->
  unit Current.or_error
