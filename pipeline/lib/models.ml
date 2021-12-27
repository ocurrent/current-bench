module Benchmark = struct
  type t = {
    version : int;
    run_at : Ptime.t;
    duration : Ptime.span;
    repo_id : string * string;
    commit : string;
    branch : string option;
    pull_number : int option;
    build_job_id : string option;
    run_job_id : string option;
    worker : string;
    docker_image : string;
    benchmark_name : string option;
    test_name : string;
    test_index : int;
    metrics : Yojson.Safe.t;
  }

  let make ~version ?build_job_id ?run_job_id ~run_at ~duration ~worker
      ~docker_image ~benchmark_name ~test_index ~repository data =
    let test_name = Yojson.Safe.Util.(member "name" data |> to_string) in
    let metrics = Yojson.Safe.Util.(member "metrics" data) in
    {
      version;
      run_at;
      duration;
      repo_id = Repository.id repository;
      commit = Repository.commit_hash repository;
      branch = Repository.branch repository;
      pull_number = Repository.pull_number repository;
      build_job_id;
      run_job_id;
      worker;
      docker_image;
      benchmark_name;
      test_name;
      test_index;
      metrics;
    }

  let version self = self.version

  let run_at self = self.run_at

  let duration self = self.duration

  let repo_id self = self.repo_id

  let commit self = self.commit

  let branch self = self.branch

  let pull_number self = self.pull_number

  let build_job_id self = self.build_job_id

  let run_job_id self = self.run_job_id

  let test_name self = self.test_name

  let benchmark_name self = self.benchmark_name

  let test_index self = self.test_index

  let metrics self = self.metrics

  let worker self = self.worker

  let docker_image self = self.docker_image

  let pp =
    let open Fmt.Dump in
    record
      [
        field "version" version Fmt.int;
        field "run_at" run_at Ptime.pp;
        field "duration" duration Ptime.Span.pp;
        field "repo_id" repo_id Fmt.(pair ~sep:(Fmt.any "/") string string);
        field "commit" commit Fmt.string;
        field "branch" branch Fmt.(option string);
        field "pull_number" pull_number Fmt.(option int);
        field "build_job_id" build_job_id Fmt.(option string);
        field "run_job_id" run_job_id Fmt.(option string);
        field "worker" worker Fmt.string;
        field "docker_image" docker_image Fmt.string;
        field "benchmark_name" benchmark_name Fmt.(option string);
        field "test_name" test_name Fmt.(string);
        field "test_index" test_index Fmt.(int);
        field "metrics" metrics Yojson.Safe.pp;
      ]

  module Db = struct
    let insert_query self =
      let version = Db_util.int self.version in
      let run_at = Db_util.time self.run_at in
      let duration = Db_util.span self.duration in
      let repository =
        Db_util.string (fst self.repo_id ^ "/" ^ snd self.repo_id)
      in
      let commit = Db_util.string self.commit in
      let branch = Db_util.(option string) self.branch in
      let pull_number = Db_util.(option int) self.pull_number in
      let build_job_id = Db_util.(option string) self.build_job_id in
      let run_job_id = Db_util.(option string) self.run_job_id in
      let benchmark_name = Db_util.(option string) self.benchmark_name in
      let test_name = Db_util.(string) self.test_name in
      let test_index = Db_util.(int) self.test_index in
      let metrics = Db_util.json self.metrics in
      let worker = Db_util.string self.worker in
      let docker_image = Db_util.string self.docker_image in
      Fmt.str
        {|INSERT INTO benchmarks(version, run_at, duration, repo_id, commit, branch, pull_number, build_job_id, run_job_id, worker, docker_image, benchmark_name, test_name,  test_index, metrics)
          VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
          ON CONFLICT (commit, test_name, run_job_id)
          DO UPDATE SET metrics = EXCLUDED.metrics
        |}
        version run_at duration repository commit branch pull_number
        build_job_id run_job_id worker docker_image benchmark_name test_name
        test_index metrics

    let insert self (db : Postgresql.connection) =
      let query = insert_query self in
      try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
      | Postgresql.Error err ->
          Logs.err (fun log ->
              log "Could not insert results:\n%s"
                (Postgresql.string_of_error err))
      | exn ->
          Logs.err (fun log -> log "Could not insert results:\n%a" Fmt.exn exn)

    let insert ~conninfo self = Db_util.with_db ~conninfo (insert self)

    let exists_query ~repository =
      let repo_id = Db_util.string @@ Repository.info repository
      and commit = Db_util.string @@ Repository.commit_hash repository in
      (* NOTE: We check if an entry exists in the benchmarks table, and not the
         benchmarks_metadata table since we want to re-run the benchmarks if
         the failure occurred due to a current-bench pipeline related error
         like DB write error, running out of space, incorrectly solving opam
         dependencies, etc. *)
      Fmt.str "SELECT COUNT(*) FROM benchmarks WHERE repo_id=%s AND commit=%s"
        repo_id commit

    let exists repository (db : Postgresql.connection) =
      let query = exists_query ~repository in
      let result = db#exec query in
      match result#get_all with
      | [| [| count_str |] |] ->
          let count = int_of_string count_str in
          count >= 1
      | result ->
          Logs.err (fun log ->
              log "Unexpected result for Db.exists %s:%s\n%a"
                (Repository.info repository)
                (Repository.commit_hash repository)
                (Fmt.array (Fmt.array Fmt.string))
                result);
          true
      | exception exn ->
          Logs.err (fun log ->
              log "Error for Db.exists %s:%s\n%a"
                (Repository.info repository)
                (Repository.commit_hash repository)
                Fmt.exn exn);
          true

    let exists ~conninfo repository =
      Db_util.with_db ~conninfo (exists repository)
  end
end
