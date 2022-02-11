open Lwt.Infix
module Utils = Cohttp_lwt_unix

exception Invalid_token
exception Missing_token
exception Unauthorized
exception Server_config_error
exception Data_validation_error of string

let request_token req =
  let headers = Cohttp.Request.headers req in
  let token = Cohttp.Header.get headers "Authorization" in
  let open String in
  match token with
  | Some token ->
      if starts_with ~prefix:"Bearer " token
      then
        let n = length token in
        let m = length "Bearer " in
        sub token m (n - m)
      else raise Invalid_token
  | _ -> raise Missing_token

let authenticate_token req api_tokens =
  (* This function only that the token is a valid token, and doesn't process
     the body of the request. Essentially, we only do "authentication" of the
     token. The authorization is done in a separate function.*)
  (match api_tokens with [] -> raise Server_config_error | _ -> ());

  let token = request_token req in
  match token with
  | "" -> raise Missing_token
  | _ ->
      List.find_opt
        (fun (t : Config.api_token) -> String.equal t.token token)
        api_tokens

let authorize_token (api_token : Config.api_token option) repository =
  let repo_id = Repository.info repository in
  match api_token with
  | Some api_token ->
      if String.equal api_token.repo repo_id then () else raise Unauthorized
  | _ -> raise Invalid_token

let check_key key json =
  match Yojson.Safe.Util.(member key json) with
  | `Null -> Data_validation_error (Fmt.str "Key '%s' is missing" key) |> raise
  | s -> s

let make_benchmark_from_request ~conninfo ~body ~token =
  let json_body = body |> Yojson.Safe.from_string in
  let open Yojson.Safe.Util in
  let repository_name = check_key "repo_name" json_body |> to_string in
  let repository_owner = check_key "repo_owner" json_body |> to_string in
  let branch = member "branch" json_body |> to_string_option in
  let pull_number = member "pull_number" json_body |> to_int_option in
  (match (branch, pull_number) with
  | None, None ->
      Data_validation_error "Need either 'branch' or 'pull_number'" |> raise
  | _ -> ());
  let commit = check_key "commit" json_body |> to_string in
  let run_at =
    check_key "run_at" json_body |> to_string |> Ptime.of_rfc3339 |> function
    | Ok (t, _, _) -> t
    | Error (`RFC3339 (_, e)) ->
        Data_validation_error (Fmt.str "%a" Ptime.pp_rfc3339_error e) |> raise
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
  authorize_token token repository;
  let serial_id =
    Storage.setup_metadata ~repository ~conninfo ~worker ~docker_image
  in
  ignore
    (benchmarks
    |> List.map (fun bench ->
           Json_stream.db_save ~conninfo benchmark
             [ Current_bench_json.of_json bench ]));
  Storage.record_success ~conninfo ~serial_id

let error_message msg =
  `Assoc [ ("success", `Bool false); ("error", `String msg) ]

let capture_metrics conninfo api_tokens =
  object
    inherit Current_web.Resource.t

    method! post_raw _ req body =
      Cohttp_lwt.Body.to_string body >>= fun body ->
      let status, response =
        try
          let token = authenticate_token req api_tokens in
          make_benchmark_from_request ~conninfo ~body ~token;
          let status = `OK in
          let response = `Assoc [ ("success", `Bool true) ] in
          (status, response)
        with
        | Yojson.Json_error e
        | Yojson.Safe.Util.Type_error (e, _)
        | Data_validation_error e ->
            (`Bad_request, error_message e)
        | Invalid_token -> (`Unauthorized, error_message "Invalid token")
        | Missing_token -> (`Unauthorized, error_message "Token missing")
        | Unauthorized ->
            (`Forbidden, error_message "Token not valid for this repo")
        | Server_config_error ->
            (`Internal_server_error, error_message "API tokens not configured.")
      in
      let body =
        response |> Yojson.Safe.to_string |> Cohttp_lwt.Body.of_string
      in
      Utils.Server.respond ~status ~body ()
  end
