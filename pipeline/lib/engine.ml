module Git = Current_git

type output = Yojson.Safe.t list

module type S = sig
  type state

  val build :
    pool:unit Current.Pool.t ->
    Commit_context.t ->
    Git.Commit.t Current.t ->
    state Current.t

  val run : config:Config.t -> state Current.t -> output Current.t

  val complete : Commit_context.t -> state -> output Current.t -> unit Current.t
end

module Docker_engine : S = struct
  module Docker = Current_docker.Default
  open Current.Syntax

  let cmd_args_of_config (config : Config.t) =
    let cpuset_cpus =
      match config.docker_cpuset_cpus with
      | Some cpu -> [ "--cpuset-cpus"; cpu ]
      | None -> []
    in
    let cpuset_mems =
      match config.docker_numa_node with
      | Some i -> [ "--cpuset-mems"; string_of_int i ]
      | None -> []
    in
    let tmpfs =
      match config.docker_numa_node with
      | Some i ->
          [
            "--tmpfs";
            Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d"
              config.docker_shm_size i;
          ]
      | None ->
          [
            "--tmpfs";
            Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" config.docker_shm_size;
          ]
    in
    List.concat [ cpuset_cpus; cpuset_mems; tmpfs ]

  let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 1) ()

  type state = Docker.Image.t

  let dockerfile ~base =
    let open Dockerfile in
    from (Docker.Image.hash base)
    @@ run
         "sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
          liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev"
    @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"bench-dir" ()
    @@ workdir "bench-dir"
    @@ run "opam remote add origin https://opam.ocaml.org"
    @@ run "opam install -y --deps-only -t ."
    @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
    @@ run "eval $(opam env)"

  let build ~pool (_commit_context : Commit_context.t) commit =
    let dockerfile =
      let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
      `Contents (dockerfile ~base)
    in
    Docker.build ~pool ~pull:false ~dockerfile (`Git commit)

  let run ~(config : Config.t) state =
    let run_args =
      [ "--security-opt"; "seccomp=./aslr_seccomp.json" ]
      @ cmd_args_of_config config
    in
    let current_image = state in
    let current_output =
      Docker.pread ~run_args current_image
        ~args:
          [
            "/usr/bin/setarch"; "x86_64"; "--addr-no-randomize"; "make"; "bench";
          ]
    in
    let* output = current_output in
    let json_list = Json_util.parse_many output in
    Current.return json_list

  let complete _commit_context _state _output = Current.return ()
end
