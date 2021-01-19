module Benchmark : sig
  type t

  val make :
    run_at:Ptime.t ->
    duration:Ptime.span ->
    repo_id:string * string ->
    commit:string ->
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

  val name : t -> string option

  val data : t -> Yojson.Safe.t

  val pp : t Fmt.t

  module Db : sig
    val insert : Postgresql.connection -> t -> unit
  end
end
