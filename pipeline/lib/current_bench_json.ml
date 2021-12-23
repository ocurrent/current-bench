(* Warning: This file is used in the pipeline AND the frontend.
 * It must remain compatible with Rescript ~= OCaml 4.06 with a few missing stdlib modules
 * and must have no external dependency.
 *)

module Json = struct
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

  let member field = function
    | `Assoc obj -> (
        match List.assoc_opt field obj with None -> `Null | Some x -> x)
    | _ -> `Null

  let to_string_option = function `String s -> Some s | _ -> None

  let to_int_option = function `Int s -> Some s | _ -> None

  let to_list = function `List xs -> xs | _ -> invalid_arg "Json: not a list"

  let to_assoc = function
    | `Assoc xs -> xs
    | _ -> invalid_arg "Json: not a list"

  let get = member

  let to_string = function
    | `String s -> s
    | `Null -> invalid_arg "Json: not a string but a null"
    | `Bool _ -> invalid_arg "Json: not a string but a bool"
    | `Int _ -> invalid_arg "Json: not a string int"
    | `Intlit _ -> invalid_arg "Json: not a string intlit"
    | `Float _ -> invalid_arg "Json: not a string float"
    | `Assoc _ -> invalid_arg "Json: not a string assoc"
    | `List _ -> invalid_arg "Json: not a string list"
    | `Tuple _ -> invalid_arg "Json: not a string tuple"
    | `Variant _ -> invalid_arg "Json: not a string variant"
    | _ -> invalid_arg "Json: not a string"

  let to_float = function
    | `Float x -> x
    | `Int x -> float_of_int x
    | _ -> invalid_arg "Json: not a float"
end

let default d = function None -> d | Some x -> x

let rec list_find_map f = function
  | [] -> raise Not_found
  | x :: xs -> ( match f x with Some y -> y | None -> list_find_map f xs)

let scanf fmt fn ~str = try Some (Scanf.sscanf str fmt fn) with _ -> None

module V2 = struct
  let version = 2

  type value =
    | Float of float
    | Floats of float list
    | Assoc of (string * float) list

  type metric = {
    name : string;
    description : string;
    value : value;
    units : string;
  }

  type result = { test_name : string; metrics : metric list }

  type t = { benchmark_name : string option; results : result list }

  let value_of_json = function
    | `Float x -> (x, "")
    | `Int x -> (float_of_int x, "")
    | `Intlit s -> (float_of_string s, "")
    | `String str ->
        list_find_map
          (fun f -> f ~str)
          [
            scanf "%fmin%fs" (fun min sec -> ((min *. 60.) +. sec, "s"));
            scanf "%f%s" (fun x u -> (x, u));
          ]
    | _ -> failwith "V2: not a value"

  let value_of_json = function
    | `List vs ->
        let vs, units = List.split @@ List.map value_of_json vs in
        (Floats vs, units)
    | `Assoc vs ->
        let vs, units =
          let keys = List.map (fun (key, _) -> key) vs in
          if not (List.mem "avg" keys)
          then failwith "V2: Missing key *avg* in value";
          List.split
          @@ List.map
               (fun (key, v) ->
                 let value, units = value_of_json v in
                 ((key, value), units))
               vs
        in
        (Assoc vs, units)
    | v ->
        let v, unit = value_of_json v in
        (Float v, [ unit ])

  let json_of_value = function
    | Float f -> `Float f
    | Floats fs -> `List (List.map (fun f -> `Float f) fs)
    | Assoc fs -> `Assoc (List.map (fun (x, f) -> (x, `Float f)) fs)

  let rec find_units = function
    | [] -> ""
    | x :: _ when x <> "" -> x
    | _ :: xs -> find_units xs

  let value_of_json ?(units = "") t =
    let value, units_list = value_of_json t in
    let units = find_units (units :: units_list) in
    (value, units)

  let metric_of_json t =
    let units = Json.get "units" t |> Json.to_string_option |> default "" in
    let description =
      Json.get "description" t |> Json.to_string_option |> default ""
    in
    let value, units = value_of_json ~units (Json.get "value" t) in
    { name = Json.get "name" t |> Json.to_string; description; value; units }

  let json_of_metric m =
    `Assoc
      [
        ("name", `String m.name);
        ("description", `String m.description);
        ("value", json_of_value m.value);
        ("units", `String m.units);
      ]

  let json_of_metrics metrics = `List (List.map json_of_metric metrics)

  let json_of_result m =
    `Assoc
      [ ("name", `String m.test_name); ("metrics", json_of_metrics m.metrics) ]

  let result_of_json t =
    {
      test_name = Json.get "name" t |> Json.to_string;
      metrics = Json.get "metrics" t |> Json.to_list |> List.map metric_of_json;
    }

  let of_json t =
    {
      benchmark_name = Json.get "name" t |> Json.to_string_option;
      results = Json.get "results" t |> Json.to_list |> List.map result_of_json;
    }
end

module V1 = struct
  let version = 1

  type value = V2.value

  type metric = V2.metric

  type result = V2.result

  type t = V2.t

  let metric_of_json (name, value) =
    let value, units = V2.value_of_json value in
    let description = "" in
    { V2.name; description; value; units }

  let result_of_json t =
    {
      V2.test_name = Json.get "name" t |> Json.to_string;
      metrics = Json.get "metrics" t |> Json.to_assoc |> List.map metric_of_json;
    }

  let of_json t =
    {
      V2.benchmark_name = Json.get "name" t |> Json.to_string_option;
      results = Json.get "results" t |> Json.to_list |> List.map result_of_json;
    }

  let to_v2 t = t
end

module Latest = V2

let of_json json =
  match Json.get "version" json with
  | `Int 2 -> V2.of_json json
  | _ -> V1.to_v2 @@ V1.of_json json

let validate t =
  let tbl = Hashtbl.create 16 in
  let open Latest in
  List.iter
    (fun result ->
      let key = result.benchmark_name in
      match Hashtbl.find_opt tbl key with
      | Some _ ->
          failwith
            "This benchmark name already exists, please create a unique name"
      | None ->
          Hashtbl.add tbl key
            (Latest.version, List.map json_of_result result.results))
    t;
  tbl
