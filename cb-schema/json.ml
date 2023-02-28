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

(* Yojson.Safe printing functions reproduced *)

let pp_list sep ppx out l =
  let pp_sep out () = Format.fprintf out "%s@ " sep in
  Format.pp_print_list ~pp_sep ppx out l

let is_atom : t -> bool = function
  | `Null | `Bool _ | `Int _ | `Float _ | `String _ | `Intlit _
  | `List []
  | `Assoc []
  | `Tuple []
  | `Variant (_, None) ->
      true
  | `List _ | `Assoc _ | `Tuple _ | `Variant (_, Some _) -> false

let is_atom_list l = List.for_all is_atom l

(*
     inside_box: indicates that we're already within a box that imposes
     a certain style and we shouldn't create a new one. This is used for
     printing field values like this:
       foo: [
         bar
       ]
     rather than something else like
       foo:
         [
           bar
         ]
  *)
let rec format ~inside_box out (x : t) =
  match x with
  | `Null -> Format.pp_print_string out "null"
  | `Bool x -> Format.pp_print_bool out x
  | `Int x -> Format.pp_print_int out x
  | `Float x -> Format.pp_print_float out x
  | `String s -> Format.fprintf out "%S" s
  | `Intlit s -> Format.pp_print_string out s
  | `List [] -> Format.pp_print_string out "[]"
  | `List l ->
      if not inside_box then Format.fprintf out "@[<hv2>";
      if is_atom_list l
      then
        (* use line wrapping like we would do for a paragraph of text *)
        Format.fprintf out "[@;<1 0>@[<hov>%a@]@;<1 -2>]"
          (pp_list "," (format ~inside_box:false))
          l
      else
        (* print the elements horizontally if they fit on the line,
           otherwise print them in a column *)
        Format.fprintf out "[@;<1 0>@[<hv>%a@]@;<1 -2>]"
          (pp_list "," (format ~inside_box:false))
          l;
      if not inside_box then Format.fprintf out "@]"
  | `Assoc [] -> Format.pp_print_string out "{}"
  | `Assoc l ->
      if not inside_box then Format.fprintf out "@[<hv2>";
      Format.fprintf out "{@;<1 0>%a@;<1 -2>}" (pp_list "," format_field) l;
      if not inside_box then Format.fprintf out "@]"
  | `Tuple l ->
      if l = []
      then Format.pp_print_string out "()"
      else (
        if not inside_box then Format.fprintf out "@[<hov2>";
        Format.fprintf out "(@,%a@;<0 -2>)"
          (pp_list "," (format ~inside_box:false))
          l;
        if not inside_box then Format.fprintf out "@]")
  | `Variant (s, None) -> Format.fprintf out "<%s>" s
  | `Variant (s, Some x) ->
      Format.fprintf out "<@[<hv2>%s: %a@]>" s (format ~inside_box:true) x

and format_field out (name, x) =
  Format.fprintf out "@[<hv2>%s: %a@]" name (format ~inside_box:true) x

let pp out (x : t) =
  Format.fprintf out "@[<hv2>%a@]" (format ~inside_box:true) (x :> t)

let pp_to_string () x = Format.asprintf "%a" pp x

let to_channel oc x =
  let fmt = Format.formatter_of_out_channel oc in
  Format.fprintf fmt "%a@?" pp x

let error expected gotten =
  invalid_arg
  @@ Format.sprintf
       "Json type error: the expected type was `%s`, but the value didn't fit. \
        If it is indeed the correct type, please report.@;\
        The value was: @[%a@]@;"
       expected pp_to_string gotten

let member field = function
  | `Assoc obj -> (
      match List.assoc_opt field obj with None -> `Null | Some x -> x)
  | _ -> `Null

let to_string_option = function `String s -> Some s | _ -> None
let to_int_option = function `Int s -> Some s | _ -> None
let to_list_option = function `List xs -> Some xs | _ -> None
let to_list = function `List xs -> xs | j -> error "list" j
let to_assoc = function `Assoc xs -> xs | j -> error "json object" j
let get = member
let to_string = function `String s -> s | j -> error "string" j

let to_float = function
  | `Float x -> x
  | `Int x -> float_of_int x
  | j -> error "float" j
