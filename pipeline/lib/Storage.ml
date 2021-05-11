module Github = Current_github

let record_build_start ~run_at ~(repo_id : Github.Repo_id.t) ~pull_number
    ~branch ~commit ~build_job_id (db : Postgresql.connection) =
  let repo_id = Sql_util.string (repo_id.owner ^ "/" ^ repo_id.name) in
  let run_at = Sql_util.time run_at in
  let commit = Sql_util.string commit in
  let build_job_id = Sql_util.string build_job_id in
  let branch = Sql_util.(option string) branch in
  let pull_number = Sql_util.(option int) pull_number in
  let query =
    Fmt.str
      {|
INSERT INTO
  benchmarks(run_at, repo_id, commit, branch, pull_number, build_job_id)
VALUES
  (%s, %s, %s, %s, %s, %s)
|}
      run_at repo_id commit branch pull_number build_job_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error: %s" (Postgresql.string_of_error err))
  | exn -> Logs.err (fun log -> log "Unknown error:\n%a" Fmt.exn exn)

let record_run_start ~(repo_id : Github.Repo_id.t) ~build_job_id ~run_job_id
    (db : Postgresql.connection) =
  let repo_id = Sql_util.string (repo_id.owner ^ "/" ^ repo_id.name) in
  let build_job_id = Sql_util.string build_job_id in
  let run_job_id = Sql_util.string run_job_id in
  let query =
    Fmt.str
      {|
UPDATE benchmarks
SET
  run_job_id = %s
WHERE
  repo_id = %s
AND
  build_job_id = %s
|}
      run_job_id repo_id build_job_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error: %s" (Postgresql.string_of_error err))
  | exn -> Logs.err (fun log -> log "Unknown error:\n%a" Fmt.exn exn)

let record_run_finish ~(repo_id : Github.Repo_id.t) ~build_job_id
    ~output:(_ : Yojson.Safe.t list) (db : Postgresql.connection) =
  let output = Sql_util.json (`String "TODO") in
  let repo_id = Sql_util.string (repo_id.owner ^ "/" ^ repo_id.name) in
  let build_job_id = Sql_util.string build_job_id in
  let query =
    Fmt.str
      {|
UPDATE benchmarks
SET
  output = %s
WHERE
  repo_id = %s
AND
  build_job_id = %s
|}
      output repo_id build_job_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error: %s" (Postgresql.string_of_error err))
  | exn -> Logs.err (fun log -> log "Unknown error:\n%a" Fmt.exn exn)
