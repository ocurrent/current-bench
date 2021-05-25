module Docker = struct
  type t = { cpuset_cpus : int option; numa_node : int option; shm_size : int }
  [@@deriving make]
end

module Slack = struct
  type t = { path : Fpath.t option }
end

type t = { docker : Docker.t; slack : Slack.t }
