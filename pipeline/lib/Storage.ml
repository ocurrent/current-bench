let record_build_start ~(repo_id : string) ~pull_number ~branch ~commit
    ~build_job_id (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording build start...");
  let repo_id = Sql_util.string repo_id in
  let commit = Sql_util.string commit in
  let build_job_id = Sql_util.string build_job_id in
  let branch = Sql_util.(option string) branch in
  let pull_number = Sql_util.(option int) pull_number in
  let query =
    Fmt.str
      {|
INSERT INTO
  benchmarks_new(repo_id, commit, branch, pull_number, build_job_id, status)
VALUES
  (%s, %s, %s, %s, %s, 'build_started')
ON CONFLICT DO NOTHING
|}
      repo_id commit branch pull_number build_job_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error: %s" (Postgresql.string_of_error err))
  | exn -> Logs.err (fun log -> log "Unknown error:\n%a" Fmt.exn exn)

let record_run_start ~repo_id_string ~build_job_id ~run_job_id
    (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording run start...");
  let repo_id_string = Sql_util.string repo_id_string in
  let build_job_id = Sql_util.string build_job_id in
  let run_job_id = Sql_util.string run_job_id in
  let query =
    Fmt.str
      {|
UPDATE benchmarks_new
SET
  run_job_id = %s,
  status = 'run_started'
WHERE
  repo_id = %s
AND
  build_job_id = %s
|}
      run_job_id repo_id_string build_job_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error: %s" (Postgresql.string_of_error err))
  | exn -> Logs.err (fun log -> log "Unknown error:\n%a" Fmt.exn exn)

let record_run_finish ~repo_id_string ~build_job_id ~run_job_id
    ~(output : Yojson.Safe.t list) (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording run finish...");
  let output = Sql_util.json (`List output) in
  let repo_id_string = Sql_util.string repo_id_string in
  let build_job_id = Sql_util.string build_job_id in
  let run_job_id = Sql_util.string run_job_id in
  let query =
    Fmt.str
      {|
UPDATE benchmarks_new
SET
  run_job_id = %s,
  output = %s,
  status = 'run_succeeded'
WHERE
  repo_id = %s
AND
  build_job_id = %s
|}
      run_job_id output repo_id_string build_job_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error: %s" (Postgresql.string_of_error err))
  | exn -> Logs.err (fun log -> log "Unknown error:\n%a" Fmt.exn exn)
