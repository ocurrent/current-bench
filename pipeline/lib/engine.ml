module Git = Current_git

type output = Yojson.Safe.t list

module type S = sig
  type state

  val build :
    pool:unit Current.Pool.t ->
    Repository.t ->
    Git.Commit.t Current.t ->
    state Current.t

  val run : pool:unit Current.Pool.t -> state Current.t -> output Current.t

  val complete : Repository.t -> state -> output Current.t -> unit Current.t
end

module Docker_engine = struct
  module Docker = Current_docker.Default

  let build ~pool ~(repository : Repository.t) =
    let dockerfile = Custom_dockerfile.dockerfile ~pool ~repository in
    let commit = Repository.src repository in
    Docker.build ~pool ~pull:false ~dockerfile (`Git commit)

  let run ?info ~pool ~run_args current_image =
    Current_util.Docker.pread_log ?info ~pool ~run_args current_image
      ~args:
        [
          "/usr/bin/setarch";
          "x86_64";
          "--addr-no-randomize";
          "sh";
          "-c";
          "opam exec -- make bench";
        ]

  let complete _commit_context _state _output = Current.return ()
end
