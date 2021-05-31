module Docker = struct
  type t = {
    cpuset_cpus : string option;
    numa_node : int option;
    shm_size : int;
  }
  [@@deriving make]

  let to_cmd_args t =
    let cpuset_cpus =
      match t.cpuset_cpus with
      | Some cpu -> [ "--cpuset-cpus"; cpu ]
      | None -> []
    in
    let cpuset_mems =
      match t.numa_node with
      | Some i -> [ "--cpuset-mems"; string_of_int i ]
      | None -> []
    in
    let tmpfs =
      match t.numa_node with
      | Some i ->
          [
            "--tmpfs";
            Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d" t.shm_size
              i;
          ]
      | None ->
          [ "--tmpfs"; Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" t.shm_size ]
    in
    List.concat [ cpuset_cpus; cpuset_mems; tmpfs ]
end

type t = { docker : Docker.t; slack_path : Fpath.t option; db_uri : Uri.t }
