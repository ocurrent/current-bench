type t =
  (* Yojson.Safe.t = *)
  [ `Null
  | `Bool of bool
  | `Int of int
  | `Intlit of string
  | `Float of float
  | `String of string
  | `Assoc of (string * t) list
  | `List of t list
  | `Tuple of t list
  | `Variant of string * t option ]

let error key value_type value =
  match value with
  | `Null -> invalid_arg @@ Format.sprintf "Mandatory key %S not found." key
  | _ ->
      invalid_arg
      @@ Format.sprintf
           "The value of key %S had an expected type of `%s`, but the value \
            didn't fit."
           key value_type

let get_opt key = function
  | `Assoc obj -> (
      match List.assoc_opt key obj with None -> `Null | Some x -> x)
  | _ -> `Null

let to_string_option = function `String s -> Some s | _ -> None
let to_int_option = function `Int s -> Some s | _ -> None
let to_list_option = function `List xs -> Some xs | _ -> None
let to_list key = function `List xs -> xs | j -> error key "list" j

let get ?(context = "") key j =
  let err () =
    error
      (if context = "" then key else context ^ "/" ^ key)
      "json object" `Null
  in
  match get_opt key j with `Null -> err () | x -> x

let to_string key = function `String s -> s | j -> error key "string" j

let to_float key = function
  | `Float x -> x
  | `Int x -> float_of_int x
  | j -> error key "float" j
