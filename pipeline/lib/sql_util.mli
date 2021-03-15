type value = string

val option : ('a -> value) -> 'a option -> value

val json : Yojson.Safe.t -> value

val string : string -> value

val int : int -> value

val time : Ptime.t -> value

val span : Ptime.span -> value
