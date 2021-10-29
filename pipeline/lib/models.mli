module Benchmark : sig
  type t

  val make :
    version:int ->
    ?build_job_id:string ->
    ?run_job_id:string ->
    run_at:Ptime.t ->
    duration:Ptime.span ->
    benchmark_name:string option ->
    repository:Repository.t ->
    Yojson.Safe.t ->
    t

  val version : t -> int

  val run_at : t -> Ptime.t

  val duration : t -> Ptime.span

  val repo_id : t -> string * string

  val commit : t -> string

  val branch : t -> string option

  val pull_number : t -> int option

  val build_job_id : t -> string option

  val run_job_id : t -> string option

  val test_name : t -> string

  val benchmark_name : t -> string option

  val metrics : t -> Yojson.Safe.t

  val pp : t Fmt.t

  module Db : sig
    val insert : Postgresql.connection -> t -> unit

    val exists : Postgresql.connection -> Repository.t -> bool
  end
end
