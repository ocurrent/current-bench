val read_fpath : Fpath.t -> string

val merge_json :
  repo:string -> owner:string -> commit:string -> string -> string list
(** [merge_json ~repo ~owner ~commit multi_json] is a list of JSON strings
    containing benchmarking results for a given [repo], [owner] and [commit].
    The results are obtained from the multi-object [multi_json] string. *)

val populate_postgres :
  conninfo:string ->
  commit:string ->
  json_string:string ->
  pr_info:string ->
  unit
