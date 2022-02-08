type t = string

let with_db ~conninfo fn =
  let db = new Postgresql.connection ~conninfo () in
  Fun.protect ~finally:(fun () -> db#finish) (fun () -> fn db)

let check_connection ~conninfo =
  try
    let db = new Postgresql.connection ~conninfo () in
    let query = "SELECT 1" in
    ignore (db#exec ~expect:[ Postgresql.Tuples_ok ] query);
    db#finish
  with
  | Postgresql.Error err as exn ->
      Logs.err (fun log ->
          log "Database connection error:\n%s" (Postgresql.string_of_error err));
      raise exn
  | exn ->
      Logs.err (fun log -> log "Database connection error:\n%a" Fmt.exn exn);
      raise exn

let option f = function Some x -> f x | None -> "NULL"
let time x = "to_timestamp(" ^ string_of_float (Ptime.to_float_s x) ^ ")"

let span x =
  let seconds = Ptime.Span.to_float_s x in
  "make_interval(secs => " ^ string_of_float seconds ^ ")"

let int = string_of_int

let string x =
  let x = x |> String.split_on_char '\'' |> String.concat "''" in
  "'" ^ x ^ "'"

let json x = string (Yojson.Safe.to_string x)
