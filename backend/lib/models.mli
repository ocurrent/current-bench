module Benchmark : sig
  type t

  val make :
    run_at:Ptime.t ->
    repo_id:string * string ->
    commit:string ->
    duration:Ptime.span ->
    benchmark_name:string option ->
    ?branch:string ->
    ?pull_number:int ->
    Yojson.Safe.t ->
    t

  val run_at : t -> Ptime.t

  val duration : t -> Ptime.span

  val repo_id : t -> string * string

  val commit : t -> string

  val branch : t -> string option

  val pull_number : t -> int option

  val test_name : t -> string

  val benchmark_name : t -> string option

  val metrics : t -> Yojson.Safe.t

  val pp : t Fmt.t

  module Db : sig
    val insert : Postgresql.connection -> t -> unit
  end
end
