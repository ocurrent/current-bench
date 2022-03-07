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
  let to_list_option = function `List xs -> Some xs | _ -> None
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

  type line_range = int * int

  type metric = {
    name : string;
    description : string;
    value : value;
    units : string;
    trend : string;
    lines : line_range list;
  }

  type result = { test_name : string; metrics : metric list }
  type t = { benchmark_name : string option; results : result list }
  type ts = t list

  let to_floats = function
    | Float x -> [ x ]
    | Floats xs -> xs
    | Assoc lst -> List.map snd lst

  let merge_value v0 v1 =
    match (v0, v1) with
    | Assoc _, _ | _, Assoc _ ->
        invalid_arg "Multiple metrics: merge is not possible on min/avg/max"
    | _ -> Floats (to_floats v0 @ to_floats v1)

  let longest_string s0 s1 =
    if String.length s0 > String.length s1 then s0 else s1

  let merge_metric m0 m1 =
    {
      name = m0.name;
      description = longest_string m0.description m1.description;
      value = merge_value m0.value m1.value;
      units = longest_string m0.units m1.units;
      trend = longest_string m0.trend m1.trend;
      lines = m0.lines @ m1.lines;
    }

  let rec add_metric ms m =
    match ms with
    | [] -> [ m ]
    | m' :: ms when m'.name = m.name -> merge_metric m' m :: ms
    | m' :: ms -> m' :: add_metric ms m

  let merge_result r0 r1 =
    { r0 with metrics = List.fold_left add_metric r0.metrics r1.metrics }

  let rec add_results rs r =
    match rs with
    | [] -> [ r ]
    | r' :: rs when r'.test_name = r.test_name -> merge_result r' r :: rs
    | r' :: rs -> r' :: add_results rs r

  let merge_benchmark t0 t1 =
    { t0 with results = List.fold_left add_results t0.results t1.results }

  let rec add ts t =
    match ts with
    | [] -> [ t ]
    | t' :: ts when t'.benchmark_name = t.benchmark_name ->
        merge_benchmark t' t :: ts
    | t' :: ts -> t' :: add ts t

  let merge ts0 ts1 = List.fold_left add ts0 ts1

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

  let metric_of_json t lines =
    let lines =
      match Json.get "lines" t |> Json.to_list_option with
      (* NOTE: The metric JSON could either have lines or not depending on whether the JSON is
         - JSON saved in the DB using latest pipeline code, or
         - coming from make bench output, or existing JSON saved in DB created using older pipeline *)
      | Some t ->
          List.map
            (fun r ->
              match r with
              (* Frontend interprets every number as a Float, and Tuples become lists *)
              | `List [ `Float start; `Float end_ ] ->
                  (int_of_float start, int_of_float end_)
              | _ -> (-1, -1))
            t
          (* Parsing JSON from DB *)
      | _ -> lines
      (* When parsing JSON from make bench output or older JSON in DB*)
    in
    let units = Json.get "units" t |> Json.to_string_option |> default "" in
    let trend = Json.get "trend" t |> Json.to_string_option |> default "" in
    let description =
      Json.get "description" t |> Json.to_string_option |> default ""
    in
    let value, units = value_of_json ~units (Json.get "value" t) in
    let name = Json.get "name" t |> Json.to_string in
    (match trend with
    | "lower-is-better" | "higher-is-better" | "" -> ()
    | _ ->
        failwith
        @@ "V2: trend should be lower-is-better, higher-is-better or not set. "
        ^ trend
        ^ " is not valid.");
    { name; description; value; units; trend; lines }

  let metric_of_json_v1 (name, value) lines =
    let value, units = value_of_json value in
    let description = "" in
    let trend = "" in
    { name; description; value; units; trend; lines }

  let json_of_range (start, end_) = `List [ `Int start; `Int end_ ]

  let json_of_metric m =
    `Assoc
      [
        ("name", `String m.name);
        ("description", `String m.description);
        ("value", json_of_value m.value);
        ("units", `String m.units);
        ("trend", `String m.trend);
        ("lines", `List (m.lines |> List.map json_of_range));
      ]

  let json_of_metrics metrics = `List (List.map json_of_metric metrics)

  let json_of_result m =
    `Assoc
      [ ("name", `String m.test_name); ("metrics", json_of_metrics m.metrics) ]

  let metrics_of_json lines = function
    | `List lst -> List.map (fun m -> metric_of_json m lines) lst
    | `Assoc lst -> List.map (fun m -> metric_of_json_v1 m lines) lst
    | _ -> invalid_arg "Json: expected a list or an object"

  let result_of_json t lines =
    {
      test_name = Json.get "name" t |> Json.to_string;
      metrics = Json.get "metrics" t |> metrics_of_json lines;
    }

  let of_json t =
    let lines =
      match Json.get "lines" t with
      | `Tuple [ `Int start; `Int end_ ] -> [ (start, end_) ]
      | _ -> []
    in
    {
      benchmark_name = Json.get "name" t |> Json.to_string_option;
      results =
        Json.get "results" t
        |> Json.to_list
        |> List.map (fun r -> result_of_json r lines);
    }

  let to_json { benchmark_name; results } =
    let name =
      match benchmark_name with None -> `Null | Some name -> `String name
    in
    `Assoc
      [ ("name", name); ("results", `List (List.map json_of_result results)) ]
end

module Latest = V2

let version = 2
let of_json json = Latest.of_json json
let to_json t = Latest.to_json t

let of_list jsons =
  List.fold_left (fun acc json -> Latest.merge acc [ of_json json ]) [] jsons

let to_list ts =
  List.map
    (fun { Latest.benchmark_name; results } ->
      let results = List.map Latest.json_of_result results in
      (benchmark_name, version, results))
    ts
