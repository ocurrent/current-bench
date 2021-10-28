let with_connection ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty
    ?requiressl ?conninfo ?startonly f =
  let connection =
    new Postgresql.connection
      ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl
      ?conninfo ?startonly ()
  in
  let x = f connection in
  connection#finish;
  x
