let check_connection ~conninfo =
  let db = new Postgresql.connection ~conninfo () in
  let query = "SELECT 1" in
  try ignore (db#exec ~expect:[ Postgresql.Command_ok ] query) with
  | Postgresql.Error e ->
      prerr_endline "Database connection error:";
      prerr_endline (Postgresql.string_of_error e)
  | e ->
      prerr_endline "Database connection error:";
      prerr_endline (Printexc.to_string e)
