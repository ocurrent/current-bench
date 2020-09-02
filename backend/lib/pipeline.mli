module Logging = Logging

val v :
  config:Current.Config.t ->
  server:Conduit_lwt_unix.server ->
  repo:Current_github.Repo_id.t ->
  github_token:Fpath.t ->
  ?slack_path:Fpath.t ->
  ?docker_cpu:int ->
  ?docker_numa_node:int ->
  docker_shm_size:int ->
  string ->
  unit ->
  unit Current.or_error
