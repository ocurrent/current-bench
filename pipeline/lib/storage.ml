let with_db ~conninfo fn =
  let db = new Postgresql.connection ~conninfo () in
  Fun.protect ~finally:(fun () -> db#finish) (fun () -> fn db)

let setup_metadata ~repository (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Inserting metada....");
  let run_at = Sql_util.time (Ptime_clock.now ()) in
  let repo_id = Sql_util.string (Repository.info repository) in
  let commit = Sql_util.string (Repository.commit_hash repository) in
  let branch = Sql_util.(option string) (Repository.branch repository) in
  let pull_number = Sql_util.(option int) (Repository.pull_number repository) in
  let title = Sql_util.(option string) (Repository.title repository) in
  let query =
    (*
      When setting up metadata, we are only insert the details that we know at th
      beginning. If we see a conflict here, that means we have started running the
      benchmarks again for this repo and commit, so we reset the build_job_id
      and the run_job_id.
    *)
    Fmt.str
      {|
    INSERT INTO
    benchmark_metadata(run_at, repo_id, commit, branch, pull_number, pr_title)
    VALUES
    (%s, %s, %s, %s, %s, %s)
    ON CONFLICT(repo_id, commit) DO UPDATE
    set build_job_id=NULL, run_job_id=NULL, failed = false
    RETURNING id;
    |}
      run_at repo_id commit branch pull_number title
  in
  try
    let result = db#exec query in
    match result#get_all with
    | [| [| id |] |] -> int_of_string id
    | result ->
        Logs.err (fun log ->
            log "Unexpected result while setting up metadata %s:%s\n%a"
              (Repository.info repository)
              (Repository.commit_hash repository)
              (Fmt.array (Fmt.array Fmt.string))
              result);
        -1
  with exn ->
    Logs.err (fun log ->
        log "Error while setting up metadata %s:%s\n%a"
          (Repository.info repository)
          (Repository.commit_hash repository)
          Fmt.exn exn);
    -1

let setup_metadata ~repository ~conninfo =
  with_db ~conninfo (setup_metadata ~repository)

let record_stage_start ~stage ~job_id ~serial_id (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording build start...");
  let job_id = Sql_util.string job_id in
  let serial_id = Sql_util.int serial_id in
  let query =
    Fmt.str
      {|
UPDATE
  benchmark_metadata
  SET
    %s = %s
  WHERE id = %s
|}
      stage job_id serial_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error while recording stage %s: %s" stage
            (Postgresql.string_of_error err))
  | exn ->
      Logs.err (fun log ->
          log "Unknown error while recording stage %s:\n%a" stage Fmt.exn exn)

let record_stage_start ~stage ~job_id ~serial_id ~conninfo =
  with_db ~conninfo (record_stage_start ~stage ~job_id ~serial_id)

let record_stage_failure ~stage ~serial_id (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording stage failure...");
  let serial_id = Sql_util.int serial_id in
  let query =
    Fmt.str
      {|
UPDATE
  benchmark_metadata
  SET
    failed = true
    WHERE id = %s
|}
      serial_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error while recording stage failure %s: %s" stage
            (Postgresql.string_of_error err))
  | exn ->
      Logs.err (fun log ->
          log "Unknown error while recording stage failure %s:\n%a" stage
            Fmt.exn exn)

let record_stage_failure ~stage ~serial_id ~conninfo =
  with_db ~conninfo (record_stage_failure ~stage ~serial_id)

let record_cancel ~stage ~serial_id ~reason (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording stage cancel...");
  let serial_id = Sql_util.int serial_id in
  let query =
    Fmt.str
      {|
UPDATE
  benchmark_metadata
  SET
    cancelled = true,
    cancel_reason = '%s'
    WHERE id = %s
|}
      reason serial_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error while recording stage cancellation %s: %s" stage
            (Postgresql.string_of_error err))
  | exn ->
      Logs.err (fun log ->
          log "Unknown error while recording stage cancellation %s:\n%a" stage
            Fmt.exn exn)

let record_cancel ~stage ~serial_id ~reason ~conninfo =
  with_db ~conninfo (record_cancel ~stage ~serial_id ~reason)
