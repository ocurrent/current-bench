open Lwt.Infix
module Utils = Cohttp_lwt_unix

let check_key key json =
  match Yojson.Safe.Util.(member key json) with
  | `Null -> Fmt.failwith "Key '%s' is missing" key
  | s -> s

let make_benchmark_from_request ~conninfo ~body =
  let json_body = body |> Yojson.Safe.from_string in
  let open Yojson.Safe.Util in
  let repository_name = check_key "repo_name" json_body |> to_string in
  let repository_owner = check_key "repo_owner" json_body |> to_string in
  let branch = member "branch" json_body |> to_string_option in
  let pull_number = member "pull_number" json_body |> to_int_option in
  (match (branch, pull_number) with
  | None, None -> Fmt.failwith "Need either 'branch' or 'pull_number'"
  | _ -> ());
  let commit = check_key "commit" json_body |> to_string in
  let run_at =
    check_key "run_at" json_body |> to_string |> Ptime.of_rfc3339 |> function
    | Ok (t, _, _) -> t
    | Error (`RFC3339 (_, e)) -> Fmt.failwith "%a" Ptime.pp_rfc3339_error e
  in
  let duration =
    let d =
      member "duration" json_body
      |> to_string_option
      |> Option.map float_of_string
      |> Option.map Ptime.Span.of_float_s
    in
    match d with Some (Some duration) -> duration | _ -> Ptime.Span.of_int_s 0
  in
  let benchmarks = check_key "benchmarks" json_body |> to_list in
  let build_job_id = Some "" in
  let run_job_id = Some "" in
  let worker = "remote" in
  let docker_image = "external" in
  let commit =
    let open Current_git.Commit_id in
    v ~repo:"git://pipeline/" ~gref:"HEAD" ~hash:commit
  in
  let repository =
    Repository.v ?branch ?pull_number ~name:repository_name
      ~owner:repository_owner ~commit ()
  in
  let benchmark =
    Models.Benchmark.make ~duration ~run_at ~repository ~worker ~docker_image
      ?build_job_id ?run_job_id
  in
  let serial_id =
    Storage.setup_metadata ~repository ~conninfo ~worker ~docker_image
  in
  ignore
    (benchmarks
    |> List.map (fun bench ->
           Json_stream.db_save ~conninfo benchmark
             [ Current_bench_json.of_json bench ]));
  Storage.record_success ~conninfo ~serial_id

let capture_metrics conninfo =
  object
    inherit Current_web.Resource.t

    method! post_raw _ _ body =
      Cohttp_lwt.Body.to_string body >>= fun body ->
      let status, response =
        try
          make_benchmark_from_request ~conninfo ~body;
          let status = `OK in
          let response = `Assoc [ ("success", `Bool true) ] in
          (status, response)
        with
        | Yojson.Json_error e | Yojson.Safe.Util.Type_error (e, _) | Failure e
        ->
          let response =
            `Assoc [ ("success", `Bool false); ("error", `String e) ]
          in
          (`Bad_request, response)
      in
      let body =
        response |> Yojson.Safe.to_string |> Cohttp_lwt.Body.of_string
      in
      Utils.Server.respond ~status ~body ()
  end
