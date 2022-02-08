let setup_metadata ~repository ~worker ~docker_image
    (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Inserting metadata ...");
  let run_at = Db_util.time (Ptime_clock.now ()) in
  let repo_id = Db_util.string (Repository.info repository) in
  let commit = Db_util.string (Repository.commit_hash repository) in
  let branch = Db_util.(option string) (Repository.branch repository) in
  let pull_number = Db_util.(option int) (Repository.pull_number repository) in
  let title = Db_util.(option string) (Repository.title repository) in
  let worker = Db_util.string worker in
  let docker_image = Db_util.string docker_image in
  let query =
    (*
      When setting up metadata, we are only insert the details that we know at th
      beginning. If we see a conflict here, that means we have started running the
      benchmarks again for this repo and commit, so we reset the build_job_id
      and the run_job_id.
    *)
    Fmt.str
      {|INSERT INTO benchmark_metadata
          (run_at, repo_id, commit, branch, pull_number, pr_title, worker, docker_image)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT(repo_id, commit, worker, docker_image)
        DO UPDATE
        SET build_job_id = NULL,
            run_job_id = NULL,
            failed = false,
            cancelled = false,
            success = false,
            reason = ''
        RETURNING id;
      |}
      run_at repo_id commit branch pull_number title worker docker_image
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

let setup_metadata ~repository ~conninfo ~worker ~docker_image =
  Db_util.with_db ~conninfo (setup_metadata ~repository ~worker ~docker_image)

let record_stage_start ~stage ~job_id ~serial_id (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording build start...");
  let job_id = Db_util.string job_id in
  let serial_id = Db_util.int serial_id in
  let query =
    Fmt.str
      {|UPDATE benchmark_metadata
        SET %s = %s
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
  Db_util.with_db ~conninfo (record_stage_start ~stage ~job_id ~serial_id)

let record_stage_failure ~stage ~serial_id ~reason (db : Postgresql.connection)
    =
  Logs.debug (fun log -> log "Recording stage failure...");
  let serial_id = Db_util.int serial_id in
  let query =
    Fmt.str
      {|UPDATE benchmark_metadata
        SET failed = true,
            reason = %s
        WHERE id = %s
      |}
      (Db_util.string reason) serial_id
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

let record_stage_failure ~stage ~serial_id ~reason ~conninfo =
  Db_util.with_db ~conninfo (record_stage_failure ~stage ~serial_id ~reason)

let record_cancel ~stage ~serial_id ~reason (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording stage cancel...");
  let serial_id = Db_util.int serial_id in
  let query =
    Fmt.str
      {|UPDATE benchmark_metadata
        SET cancelled = true,
            reason = %s
        WHERE id = %s
      |}
      (Db_util.string reason) serial_id
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
  Db_util.with_db ~conninfo (record_cancel ~stage ~serial_id ~reason)

let record_success ~serial_id (db : Postgresql.connection) =
  Logs.debug (fun log -> log "Recording stage success...");
  let serial_id = Db_util.int serial_id in
  let query =
    Fmt.str
      {|UPDATE benchmark_metadata
        SET success = true
        WHERE id = %s
      |}
      serial_id
  in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error err ->
      Logs.err (fun log ->
          log "Database error while recording stage success %s: %s" serial_id
            (Postgresql.string_of_error err))
  | exn ->
      Logs.err (fun log ->
          log "Unknown error while recording stage success %s:\n%a" serial_id
            Fmt.exn exn)

let record_success ~serial_id ~conninfo =
  Db_util.with_db ~conninfo (record_success ~serial_id)
