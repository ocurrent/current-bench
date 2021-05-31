module Git = Current_git
module Docker_util = Current_util.Docker_util

module type S = sig
  type state

  type output

  val string_of_output : output -> string

  val build :
    pool:unit Current.Pool.t ->
    Commit_context.t ->
    Git.Commit.t Current.t ->
    state Current.t

  val run :
    config:Config.Docker.t ->
    state ->
    Commit_context.t ->
    Postgresql.connection ->
    output Current.t

  val complete :
    Commit_context.t ->
    state ->
    output ->
    Postgresql.connection ->
    unit Current.t
end

module Docker_engine : S = struct
  module Docker = Current_docker.Default
  open Current.Syntax

  let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 1) ()

  type state = { image : Docker.Image.t Current.t; build_job_id : string }

  type output = { output : Yojson.Safe.t list; run_job_id : string }

  let string_of_output t =
    String.concat "\n" (List.map Yojson.Safe.pretty_to_string t.output)

  let dockerfile ~base ~repository =
    let opam_dependencies =
      (* FIXME: This should be supported by a custom Dockerfiles. *)
      if String.equal repository "dune" then
        "opam install ./dune-bench.opam -y --deps-only  -t"
      else "opam install -y --deps-only -t ."
    in
    let open Dockerfile in
    from (Docker.Image.hash base)
    @@ run
         "sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
          liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev"
    @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"bench-dir" ()
    @@ workdir "bench-dir"
    @@ run "opam remote add origin https://opam.ocaml.org"
    @@ run "%s" opam_dependencies
    @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
    @@ run "eval $(opam env)"

  let build ~pool (_commit_context : Commit_context.t) commit =
    let dockerfile =
      let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
      (* TODO *)
      `Contents (dockerfile ~base ~repository:"x")
    in
    let image = Docker.build ~pool ~pull:false ~dockerfile (`Git commit) in
    let* build_job_id = Current_util.get_job_id image in
    match build_job_id with
    | Some build_job_id -> Current.return { image; build_job_id }
    | None ->
        Logs.err (fun log ->
            log "Could not obtain job id when building docker image");
        failwith "No build job id"

  let run ~(config : Config.Docker.t) state commit_context db =
    let repo_id_string = Commit_context.repo_id_string commit_context in
    let build_job_id = state.build_job_id in
    let run_args =
      [ "--security-opt"; "seccomp=./aslr_seccomp.json" ]
      @ Config.Docker.to_cmd_args config
    in
    let current_image = state.image in
    let commit_hash = Commit_context.hash commit_context in
    let current_output =
      Docker_util.pread_log ~run_args current_image ~repo_info:"TODO"
        ~commit_hash
        ~args:
          [
            "/usr/bin/setarch"; "x86_64"; "--addr-no-randomize"; "make"; "bench";
          ]
    in
    let* run_job_id = Current_util.get_job_id current_output
    and* output = current_output in
    match run_job_id with
    | Some run_job_id ->
        Storage.record_run_start ~repo_id_string ~build_job_id ~run_job_id db;
        Logs.debug (fun log -> log "Benchmark output:\n%s" output);
        let json_list = Json_util.parse_many output in
        Current.return { run_job_id; output = json_list }
    | _ -> failwith "No run job id"

  let complete commit_context state { output; _ } db =
    let repo_id_string = Commit_context.repo_id_string commit_context in
    let build_job_id = state.build_job_id in
    Storage.record_run_finish ~repo_id_string ~build_job_id ~output db;
    Current.return ()
end
