module Benchmark = struct
  type t = {
    run_at : Ptime.t;
    duration : Ptime.span;
    repo_id : string * string;
    commit : string;
    branch : string option;
    pull_number : int option;
    build_job_id : string option;
    run_job_id : string option;
    benchmark_name : string option;
    test_name : string;
    metrics : Yojson.Safe.t;
  }

  let make ?build_job_id ?run_job_id ~run_at ~duration ~benchmark_name
      ~repository ~commit data =
    let test_name = Yojson.Safe.Util.(member "name" data |> to_string) in
    let metrics = Yojson.Safe.Util.(member "metrics" data) in
    {
      run_at;
      duration;
      repo_id = Repository.id repository;
      commit;
      branch = Repository.branch repository;
      pull_number = Repository.pull_number repository;
      build_job_id;
      run_job_id;
      benchmark_name;
      test_name;
      metrics;
    }

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

  let metrics self = self.metrics

  let pp =
    let open Fmt.Dump in
    record
      [
        field "run_at" run_at Ptime.pp;
        field "duration" duration Ptime.Span.pp;
        field "repo_id" repo_id Fmt.(pair ~sep:(Fmt.any "/") string string);
        field "commit" commit Fmt.string;
        field "branch" branch Fmt.(option string);
        field "pull_number" pull_number Fmt.(option int);
        field "build_job_id" build_job_id Fmt.(option string);
        field "run_job_id" run_job_id Fmt.(option string);
        field "benchmark_name" benchmark_name Fmt.(option string);
        field "test_name" test_name Fmt.(string);
        field "metrics" metrics Yojson.Safe.pp;
      ]

  module Db = struct
    let insert_query self =
      let run_at = Sql_util.time self.run_at in
      let duration = Sql_util.span self.duration in
      let repository =
        Sql_util.string (fst self.repo_id ^ "/" ^ snd self.repo_id)
      in
      let commit = Sql_util.string self.commit in
      let branch = Sql_util.(option string) self.branch in
      let pull_number = Sql_util.(option int) self.pull_number in
      let build_job_id = Sql_util.(option string) self.build_job_id in
      let run_job_id = Sql_util.(option string) self.run_job_id in
      let benchmark_name = Sql_util.(option string) self.benchmark_name in
      let test_name = Sql_util.(string) self.test_name in
      let metrics = Sql_util.json self.metrics in
      Fmt.str
        {|
INSERT INTO
  benchmarks(run_at, duration, repo_id, commit, branch, pull_number, build_job_id, run_job_id, benchmark_name, test_name,  metrics)
VALUES
  (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
  ON CONFLICT (commit, test_name, run_job_id) DO NOTHING
|}
        run_at duration repository commit branch pull_number build_job_id
        run_job_id benchmark_name test_name metrics

    let insert (db : Postgresql.connection) self =
      let query = insert_query self in
      try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
      | Postgresql.Error err ->
          Logs.err (fun log ->
              log "Could not insert results:\n%s"
                (Postgresql.string_of_error err))
      | exn ->
          Logs.err (fun log -> log "Could not insert results:\n%a" Fmt.exn exn)
  end
end
