type value = string

let option f = function Some x -> f x | None -> "NULL"

let null = "NULL"

let time x = "to_timestamp(" ^ string_of_float (Ptime.to_float_s x) ^ ")"

let span x =
  let seconds = Ptime.Span.to_float_s x in
  "make_interval(secs => " ^ string_of_float seconds ^ ")"

let string x = "'" ^ x ^ "'"

let int = string_of_int

let json x = "'" ^ Yojson.Safe.to_string x ^ "'"
