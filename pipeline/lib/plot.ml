module H = Tyxml.Html
module Commits = Map.Make (String)
module Submetrics = Map.Make (String)
module Metrics = Map.Make (String)
module Tests = Map.Make (String)
module Benchmarks = Map.Make (String)
module String_map = Map.Make (String)

module M = Map.Make (struct
  type t = string * string

  let compare = Stdlib.compare
end)

type commit = string
type value = Cb_schema.S.value
type values_by_commit = value Commits.t (* indexed by commits!! *)
type values = values_by_commit Submetrics.t
type m = { units : string; values : values (* etc *) }

type t = {
  timeline : (bool * commit) list;
  colors : Color.t Submetrics.t;
  benchmarks : m Metrics.t Tests.t Benchmarks.t;
      (* benchmark_name -> test_name -> metric_name -> ? *)
}

let empty =
  {
    timeline = [];
    colors = Submetrics.(add "rest" (Color.random ()) empty);
    benchmarks = Benchmarks.empty;
  }

let add commit subkey value ms =
  let vs =
    Submetrics.find_opt subkey ms
    |> Option.value ~default:Commits.empty
    |> Commits.add commit value
  in
  let ms = Submetrics.add subkey vs ms in
  ms

let valid_parens str =
  let not_closed =
    String.fold_left
      (fun count -> function '(' -> count + 1 | ')' -> count - 1 | _ -> count)
      0 str
  in
  not_closed = 0

let add (benchmark_name, test_name, commit, json) t =
  let tests =
    try Benchmarks.find benchmark_name t.benchmarks
    with Not_found -> Tests.empty
  in
  let metrics =
    try Tests.find test_name tests with Not_found -> Metrics.empty
  in
  let colors, metrics =
    List.fold_left
      (fun (colors, acc) metric ->
        let name = metric.Cb_schema.S.name in
        let name, subkey =
          match String.split_on_char '/' name with
          | [ name; subkey ] when valid_parens name -> (name, subkey)
          | _ -> (name, "")
        in
        let m =
          try
            let m = Metrics.find name acc in
            let value =
              Units.convert_value ~from:m.units ~target:metric.units
                metric.value
            in
            if not (metric.Cb_schema.S.units = m.units)
            then
              Format.printf "mistmatch units: %S vs %S@."
                metric.Cb_schema.S.units m.units;
            (* TODO *)
            { m with values = add commit subkey value m.values }
          with Not_found ->
            let value = Commits.singleton commit metric.value in
            {
              units = metric.Cb_schema.S.units;
              values = Submetrics.singleton subkey value;
            }
        in
        let acc = Metrics.add name m acc in
        let colors =
          if Submetrics.mem subkey colors
          then colors
          else Submetrics.add subkey (Color.random ()) colors
        in
        (colors, acc))
      (t.colors, metrics) json
  in
  let tests = Tests.add test_name metrics tests in
  {
    t with
    colors;
    benchmarks = Benchmarks.add benchmark_name tests t.benchmarks;
  }

let metric_value f m =
  let open Cb_schema.S in
  match m.value with
  | Float x -> x
  | Floats xs -> f xs
  | Assoc _ -> failwith "todo assoc"

let minimum = function
  | Cb_schema.S.Float v -> v
  | Floats (v :: vs) -> List.fold_left min v vs
  | Floats [] -> assert false
  | _ -> failwith "todo assoc"

let maximum = function
  | Cb_schema.S.Float v -> v
  | Floats (v :: vs) -> List.fold_left max v vs
  | Floats [] -> assert false
  | _ -> failwith "todo assoc"

let average = function
  | Cb_schema.S.Float v -> v
  | Floats vs -> List.fold_left ( +. ) 0.0 vs /. float (List.length vs)
  | _ -> failwith "todo assoc"

let plot1_raw ~xs ~t ~subkey ys =
  let ys_min = List.map (fun (y, _, _) -> y) ys in
  let ys_avg = List.map (fun (_, y, _) -> y) ys in
  let ys_max = List.map (fun (_, _, y) -> y) ys in

  let color = Submetrics.find subkey t.colors in

  let errors =
    let ys = ys_min @ List.rev ys_max in
    `Assoc
      [
        ("x", `List (xs @ List.rev xs));
        ("y", `List ys);
        ("name", `String subkey);
        ("type", `String "scatter");
        ("line", `Assoc [ ("color", `String "transparent") ]);
        ("showlegend", `Bool false);
        ("fill", `String "tozeroy");
        ("fillcolor", `String (Color.to_css { color with Color.a = 0.2 }));
        ("hoverinfo", `String "none");
      ]
  in

  ( errors,
    `Assoc
      [
        ("x", `List xs);
        ("y", `List ys_avg);
        ("name", `String subkey);
        ("type", `String "scatter");
        ("line", `Assoc [ ("color", `String (Color.to_css color)) ]);
      ] )

let plot1 ~xs ~t ~subkey vs =
  let ys =
    List.map
      (fun (_, commit) ->
        match Commits.find commit vs with
        | Cb_schema.S.Floats [] | (exception Not_found) -> (`Null, `Null, `Null)
        | values ->
            ( `Float (minimum values),
              `Float (average values),
              `Float (maximum values) ))
      t.timeline
  in
  plot1_raw ~xs ~t ~subkey ys

let rec take n = function
  | _ when n <= 0 -> ([], [])
  | [] -> ([], [])
  | x :: xs ->
      let xs, rest = take (n - 1) xs in
      (x :: xs, rest)

let worst ~t (_, vs) =
  let _, commit = List.hd t.timeline in
  try average (Commits.find commit vs) with Not_found -> 0.0

let comparing f x y = Stdlib.compare (f y) (f x)

let summarize acc vs =
  Commits.merge
    (fun _ ox oy ->
      match (ox, oy) with
      | None, t | t, None -> t
      | Some (min, avg, max), Some (min', avg', max') ->
          Some (min +. min', avg +. avg', max +. max'))
    acc vs

let plot ~xs ~t metrics =
  let _units = metrics.units in
  let values = metrics.values in
  let plots, rest =
    Submetrics.bindings values |> List.sort (comparing (worst ~t)) |> take 5
  in
  let plots : (Yojson.Safe.t * Yojson.Safe.t) list =
    List.map (fun (subkey, vs) -> plot1 ~xs ~t ~subkey vs) plots
  in
  let rest : (Yojson.Safe.t * Yojson.Safe.t) list =
    match rest with
    | [] -> []
    | rest ->
        let rest =
          rest
          |> List.map (fun v ->
                 Commits.map (fun v -> (minimum v, average v, maximum v)) v)
          |> List.fold_left summarize Commits.empty
          |> Commits.map (fun (min, avg, max) ->
                 Cb_schema.S.Floats [ min; avg; max ])
        in
        [ plot1 ~xs ~t ~subkey:"rest" rest ]
  in
  let plots = plots @ rest in
  let bg, lines = List.split plots in
  let plotly = `List (List.rev_append bg lines) in
  H.pre [ H.txt (Yojson.Safe.pretty_to_string plotly) ]

let plot_metrics ~xs ~t metrics =
  Metrics.bindings metrics
  |> List.map (fun (plot_name, metrics) ->
         H.div
           ~a:[ H.a_class [ "plot" ] ]
           [
             H.h4 [ H.txt plot_name ];
             H.div [];
             H.div
               ~a:[ H.a_class [ "current-bench_plot" ] ]
               [ plot ~xs ~t metrics ];
           ])

let string_sub str len =
  if String.length str < len then str else String.sub str 0 len

let plot ~db ~repo_id ~pr ~worker ~docker_image =
  let ps = Storage.get_benchmarks ~db ~repo_id ~pr ~worker ~docker_image in
  let timeline : (bool * string) list =
    List.fold_left
      (fun (acc, keep) (_, _, commit, is_pr, _) ->
        if String_map.mem commit acc
        then (acc, keep)
        else (String_map.add commit () acc, (is_pr, commit) :: keep))
      (String_map.empty, []) ps
    |> snd
    |> List.rev
  in
  let t =
    List.fold_left
      (fun acc (name, test, commit, _is_pr, json_str) ->
        let jsons = Yojson.Safe.from_string json_str in
        let metrics = Cb_schema.S.metrics_of_json [] jsons in
        let entry = (name, test, commit, metrics) in
        add entry acc)
      { empty with timeline } ps
  in
  let t =
    let { colors; _ } = t in
    let nb_colors = Submetrics.cardinal colors in
    let counter = ref 0 in
    let colors =
      Submetrics.map
        (fun _ ->
          let i = !counter in
          incr counter;
          Color.v ~h:(float i /. float nb_colors) ())
        colors
    in
    assert (!counter = nb_colors);
    { t with colors }
  in

  let xs =
    List.map
      (fun (_is_pr, commit) ->
        let trunk = string_sub commit 10 in
        `String trunk)
      timeline
  in

  H.div
  @@ List.map (fun (benchmark_name, tests) ->
         H.div
           [
             H.h2 [ H.txt benchmark_name ];
             H.div
               ~a:[ H.a_id "pr_commit" ]
               [
                 H.txt
                   (match
                      List.find_opt
                        (fun (is_pr, _) -> not is_pr)
                        (List.rev timeline)
                    with
                   | Some (_, c) -> string_sub c 10
                   | None -> "");
               ];
             H.div
               ~a:[ H.a_class [ "benchmarks" ] ]
               (Tests.bindings tests
               |> List.map (fun (test_name, metrics) ->
                      H.div
                        ~a:[ H.a_class [ "benchmark" ] ]
                        [
                          H.h3 [ H.txt test_name ];
                          H.div
                            ~a:[ H.a_class [ "column" ] ]
                            (plot_metrics ~xs ~t metrics);
                        ]));
           ])
  @@ Benchmarks.bindings t.benchmarks
