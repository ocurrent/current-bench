open Utils

module Benchmark = struct
  type t = {
    run_at : Ptime.t;
    duration : Ptime.span;
    repo_id : string * string;
    commit : string;
    branch : string option;
    pull_number : int option;
    benchmark_name : string option;
    test_name : string;
    metrics : Yojson.Safe.t;
  }

  let make ~run_at ~repo_id ~commit ~duration ~benchmark_name ?branch
      ?pull_number data =
    let test_name = Yojson.Safe.Util.(member "name" data |> to_string) in
    let metrics = Yojson.Safe.Util.(member "metrics" data) in
    {
      run_at;
      duration;
      repo_id;
      commit;
      branch;
      pull_number;
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
        field "benchmark_name" benchmark_name Fmt.(option string);
        field "test_name" test_name Fmt.(string);
        field "metrics" metrics Yojson.Safe.pp;
      ]

  module Db = struct
    let insert_query
        {
          run_at;
          duration;
          repo_id;
          commit;
          branch;
          pull_number;
          benchmark_name;
          test_name;
          metrics;
        } =
      let run_at = Sql_utils.time run_at in
      let duration = Sql_utils.span duration in
      let repository = Sql_utils.string (fst repo_id ^ "/" ^ snd repo_id) in
      let commit = Sql_utils.string commit in
      let branch = Sql_utils.(option string) branch in
      let pull_number = Sql_utils.(option int) pull_number in
      let benchmark_name = Sql_utils.(option string) benchmark_name in
      let test_name = Sql_utils.(string) test_name in
      let metrics = Sql_utils.json metrics in
      Fmt.str
        {|
INSERT INTO
  benchmarks(run_at, duration, repo_id, commit, branch, pull_number, benchmark_name, test_name,  metrics)
VALUES
  (%s, %s, %s, %s, %s, %s, %s, %s, %s)
|}
        run_at duration repository commit branch pull_number benchmark_name
        test_name metrics

    let insert (db : Postgresql.connection) self =
      let query = insert_query self in
      try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
      | Postgresql.Error e -> prerr_endline (Postgresql.string_of_error e)
      | e -> prerr_endline (Printexc.to_string e)
  end
end
