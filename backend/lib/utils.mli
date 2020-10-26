val read_fpath : Fpath.t -> string

val merge_json :
  repo:string -> owner:string -> commit:string -> string -> string

val populate_postgres :
  conninfo:string ->
  commit:string ->
  json_string:string ->
  pr_info:string ->
  unit
