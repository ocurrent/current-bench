type 'a result = (string, 'a) Hashtbl.t
type 'a results = (string, 'a result) Hashtbl.t

val json_of_ols_results :
  ?name:string -> Bechamel.Analyze.OLS.t results -> Yojson.Safe.t
(** [json_of_ols_results ?name ols] is a JSON value containing a list of test
    metrics encoded from the OLS results. [name] is the name of the benchmark,
    will be omitted by default. *)
