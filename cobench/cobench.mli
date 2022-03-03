type value

val single : float -> value
val list : float list -> value

type metric

val metric :
  name:string ->
  ?description:string ->
  ?units:string ->
  ?trend:string ->
  value ->
  metric

type result

val of_metrics : name:string -> metric list -> result

type t

val of_results : result list -> t
val to_json : t -> Yojson.Safe.t
val of_json : Yojson.Safe.t -> t

module Remote : sig
  type token

  val token :
    ?url:string ->
    owner:string ->
    repo:string ->
    password:string ->
    unit ->
    token

  type branch = Branch of string | Pull_number of int

  val push :
    token:token ->
    branch:branch ->
    commit:string ->
    ?date:Ptime.t ->
    ?duration:float ->
    t ->
    unit Lwt.t
end
