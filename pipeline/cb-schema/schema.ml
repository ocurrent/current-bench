(* Added because it was introduced to stdlib in 5.0 *)
let sscanf_opt fmt fn ~str = try Some (Scanf.sscanf str fmt fn) with _ -> None

(* Added because it isn't available in reason for some reason *)
let option_value default = function None -> default | Some x -> x
let option_or o f = match o with Some x -> x | None -> f ()
let ( >>? ) = option_or

let longest_string s0 s1 =
  if String.length s0 > String.length s1 then s0 else s1

let version = 3

type value =
  | Float of float
  | Floats of float list
  | Assoc of (string * float) list

type line_range = int * int
type trend = Higher_is_better | Lower_is_better | Unspecified

type metric = {
  name : string;
  description : string;
  value : value;
  units : string;
  trend : trend;
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

let merge_trend t1 t2 =
  match (t1, t2) with
  | _ when t1 = t2 -> t1
  | x, Unspecified | Unspecified, x -> x
  | _ -> invalid_arg "Multiple metrics: merge is not possible on trends"

let merge_metric m0 m1 =
  {
    name = m0.name;
    description = longest_string m0.description m1.description;
    value = merge_value m0.value m1.value;
    units = longest_string m0.units m1.units;
    trend = merge_trend m0.trend m1.trend;
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

let value_of_json j =
  let error () = Json.error "value" "int or float, with or without unit" j in
  match j with
  | `Float x -> (x, "")
  | `Int x -> (float_of_int x, "")
  | `Intlit s -> (float_of_string_opt s >>? error, "")
  | `String str ->
      sscanf_opt "%fmin%fs" (fun min sec -> ((min *. 60.) +. sec, "s")) ~str
      >>? fun () -> sscanf_opt "%f%s" (fun x u -> (x, u)) ~str >>? error
  | _ -> error ()

let value_of_json = function
  | `List vs ->
      let vs, units = List.split @@ List.map value_of_json vs in
      (Floats vs, units)
  | `Assoc vs ->
      let vs, units =
        let keys = List.map (fun (key, _) -> key) vs in
        if not (List.mem "avg" keys)
        then invalid_arg "V3: Missing key *avg* in value";
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

let trend_of_json = function
  | `String "higher-is-better" -> Higher_is_better
  | `String "lower-is-better" -> Lower_is_better
  | `String "" | `Null -> Unspecified
  | _ ->
      invalid_arg
      @@ Format.sprintf
           "\"trend\" should be lower-is-better, higher-is-better or not set."

let metric_of_json i t lines =
  let context = Format.sprintf "results/metrics.%d" i in
  let lines =
    match Json.get_opt "lines" t |> Json.to_list_option with
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
    | None -> lines
    (* When parsing JSON from make bench output or older JSON in DB*)
  in
  let units =
    Json.get_opt "units" t |> Json.to_string_option |> option_value ""
  in
  let trend = Json.get_opt "trend" t |> trend_of_json in
  let description =
    Json.get_opt "description" t |> Json.to_string_option |> option_value ""
  in
  let value, units = value_of_json ~units (Json.get ~context "value" t) in
  let name = Json.get ~context "name" t |> Json.to_string "name" in
  { name; description; value; units; trend; lines }

let metric_of_json_v1 (name, value) lines =
  let value, units = value_of_json value in
  let description = "" in
  let trend = Unspecified in
  { name; description; value; units; trend; lines }

let json_of_range (start, end_) = `List [ `Int start; `Int end_ ]

let json_of_trend = function
  | Unspecified -> `String ""
  | Higher_is_better -> `String "higher-is-better"
  | Lower_is_better -> `String "lower-is-better"

let json_of_metric m : Json.t =
  `Assoc
    [
      ("name", `String m.name);
      ("description", `String m.description);
      ("value", json_of_value m.value);
      ("units", `String m.units);
      ("trend", json_of_trend m.trend);
      ("lines", `List (m.lines |> List.map json_of_range));
    ]

let json_of_metrics metrics = `List (List.map json_of_metric metrics)

let json_of_result m =
  `Assoc
    [ ("name", `String m.test_name); ("metrics", json_of_metrics m.metrics) ]

let metrics_of_json lines = function
  | `List lst -> List.mapi (fun i m -> metric_of_json i m lines) lst
  | `Assoc lst -> List.map (fun m -> metric_of_json_v1 m lines) lst
  | j -> Json.error "results/metrics" "list or object" j

let result_of_json t lines =
  {
    test_name =
      Json.get ~context:"results" "name" t |> Json.to_string "results/name";
    metrics = Json.get ~context:"results" "metrics" t |> metrics_of_json lines;
  }

let of_json t =
  let lines =
    match Json.get_opt "lines" t with
    | `Tuple [ `Int start; `Int finish ] -> [ (start, finish) ]
    | _ -> []
  in
  {
    benchmark_name = Json.get_opt "name" t |> Json.to_string_option;
    results =
      Json.get "results" t
      |> Json.to_list "results"
      |> List.map (fun r -> result_of_json r lines);
  }

let to_json { benchmark_name; results } =
  let name =
    match benchmark_name with None -> `Null | Some name -> `String name
  in
  `Assoc
    [ ("name", name); ("results", `List (List.map json_of_result results)) ]

let to_list ts =
  List.map
    (fun { benchmark_name; results } ->
      let results = List.map json_of_result results in
      (benchmark_name, version, results))
    ts
