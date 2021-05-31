type t = {
  current : Current.Config.t;
  docker_cpuset_cpus : string option;
  docker_numa_node : int option;
  docker_shm_size : int;
  slack_path : Fpath.t option;
  db_uri : Uri.t;
}
[@@deriving make]
