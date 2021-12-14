type t = string

let with_db ~conninfo fn =
  let db = new Postgresql.connection ~conninfo () in
  Fun.protect ~finally:(fun () -> db#finish) (fun () -> fn db)

let check_connection ~conninfo =
  try
    let db = new Postgresql.connection ~conninfo () in
    let query = "SELECT 1" in
    ignore (db#exec ~expect:[ Postgresql.Tuples_ok ] query)
  with
  | Postgresql.Error err as exn ->
      Logs.err (fun log ->
          log "Database connection error:\n%s" (Postgresql.string_of_error err));
      raise exn
  | exn ->
      Logs.err (fun log -> log "Database connection error:\n%a" Fmt.exn exn);
      raise exn
