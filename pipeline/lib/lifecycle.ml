(* (*
      build_job_id run_job_id state
      --------------------------------
      NULL         NULL       Building
      ID           NULL       Running
      ID           ID         Complete
   *)

   module Db = struct
     let build_start ~run_at ~repo_id ~pull_number ~branch ~commit
         (db : Postgresql.connection) =
       let repo_id = Sql_util.string (fst repo_id ^ "/" ^ snd repo_id) in
       let run_at = Sql_util.time run_at in
       let commit = Sql_util.string commit in
       let branch = Sql_util.(option string) branch in
       let pull_number = Sql_util.(option int) pull_number in
       let query =
         Fmt.str
           {|
     INSERT INTO
       benchmarks(run_at, repo_id, commit, branch, pull_number)
     VALUES
       (%s, %s, %s, %s, %s)
     |}
           run_at repo_id commit branch pull_number
       in
       try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
       | Postgresql.Error err ->
           Logs.err (fun log ->
               log "Database error: %s" (Postgresql.string_of_error err))
       | exn -> Logs.err (fun log -> log "Unknown error:\n%a" Fmt.exn exn)

     let build_stop ~build_job_id ~run_job_id ~benchmark_name ~test_name ~metrics
         (db : Postgresql.connection) =
       let build_job_id = Sql_util.(option string) build_job_id in
       let query =
         Fmt.str
           {|
   UPDATE
     benchmarks
   SET
     run_job_id = %s,
     benchmark_name = %s,
     test_name = %s,
     metrics = %s
   WHERE
     build_job_id = %s
   |}
           run_job_id benchmark_name test_name metrics build_job_id
       in
       try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
       | Postgresql.Error err ->
           Logs.err (fun log ->
               log "Database error: %s" (Postgresql.string_of_error err))
       | exn -> Logs.err (fun log -> log "Unknown error:\n%a" Fmt.exn exn)
   end *)
