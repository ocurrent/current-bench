module C = Current_bench_json
module L = C.Latest
module J = Yojson.Safe

type value = L.value

let single v = L.Float v
let list vs = L.Floats vs

type metric = L.metric

let metric ~name ?(description = "") ?(units = "") ?(trend = "") value =
  { L.name; description; units; trend; value; lines = [] }

type result = L.result

let of_metrics ~name ms = { L.test_name = name; metrics = ms }

type t = L.t

let of_results results = { L.benchmark_name = None; results }
let to_json = C.to_json
let of_json = C.of_json

module Remote = struct
  type token = {
    url : Uri.t;
    repo_owner : string;
    repo_name : string;
    password : string;
  }

  let token ?(url = "https://autumn.ocamllabs.io/benchmarks/metrics") ~owner
      ~repo ~password () =
    { url = Uri.of_string url; repo_owner = owner; repo_name = repo; password }

  type branch = Branch of string | Pull_number of int

  let json_of_branch = function
    | Branch br -> ("branch", `String br)
    | Pull_number pr -> ("pull_number", `Int pr)

  let json_of_ptime date =
    let date =
      match date with Some date -> date | None -> Ptime_clock.now ()
    in
    `String (Ptime.to_rfc3339 date)

  let json_of_duration = function
    | None -> []
    | Some d -> [ ("duration", `String (string_of_float d)) ]

  let push ~token ~branch ~commit ?date ?duration (benchmarks : t) =
    let json =
      `Assoc
        ([
           ("repo_owner", `String token.repo_owner);
           ("repo_name", `String token.repo_name);
           json_of_branch branch;
           ("commit", `String commit);
           ("run_at", json_of_ptime date);
           ("benchmarks", `List [ to_json benchmarks ]);
         ]
        @ json_of_duration duration)
    in
    let body = J.to_string json in
    let body = Cohttp_lwt__Body.of_string body in
    let headers =
      Cohttp.Header.of_list
        [
          ("Content-Type", "application/json");
          ("Authorization", "Bearer " ^ token.password);
        ]
    in
    let open Lwt.Syntax in
    let* _, body = Cohttp_lwt_unix.Client.post ~headers ~body token.url in
    let* body = Cohttp_lwt.Body.to_string body in
    let json = J.from_string body in
    let success = J.Util.member "success" json in
    let error = try J.Util.member "error" json with _ -> `Null in
    match (success, error) with
    | `Bool true, `Null -> Lwt.return_unit
    | `Bool false, `String msg -> Lwt.fail_with msg
    | _ -> Lwt.fail_with (J.to_string json)
end
