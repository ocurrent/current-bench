open Current.Syntax
module Git = Current_git
module Github = Current_github
module Logging = Logging
module Benchmark = Models.Benchmark
module Config = Config

let ( >>| ) x f = Current.map f x

module Source = struct
  type github = {
    token : Fpath.t;
    webhook_secret : string;
    repo : Github.Repo_id.t;
  }

  type t = Github of github | Local of Fpath.t | Github_app of Github.App.t

  let github ~token ~webhook_secret ~repo =
    Github { token; webhook_secret; repo }

  let local path = Local path
  let github_app t = Github_app t

  let webhook_secret = function
    | Local _ -> None
    | Github g -> Some g.webhook_secret
    | Github_app g -> Some (Github.App.webhook_secret g)
end

let github_status_of_state url = function
  | Ok _ -> Github.Api.Status.v ~url `Success ~description:"Passed"
  | Error (`Active _) -> Github.Api.Status.v ~url `Pending
  | Error (`Msg m) -> Github.Api.Status.v ~url `Failure ~description:m

let github_set_status ~repository result =
  match Repository.github_head repository with
  | None -> Current.ignore_value result
  | Some head ->
      let status_url = Repository.commit_status_url repository in
      Github.Api.Commit.set_status (Current.return head) "ocaml-benchmarks"
        (Current.state ~hidden:true result >>| github_status_of_state status_url)

let setup_on_cancel_hook ~job_id ~serial_id ~conninfo =
  let jobs = Current.Job.jobs () in
  match Current.Job.Map.find_opt job_id jobs with
  | Some job ->
      let _ =
        Current.Job.on_cancel job (fun m ->
            (* NOTE: on_cancel hooks also get called when the job ends, not
               just when the job is cancelled! *)
            (match m with
            | "Job complete" -> Logs.debug (fun log -> log "%s: %s\n" m job_id)
            | _ -> Storage.record_cancel ~serial_id ~reason:m ~conninfo);
            Lwt.return_unit)
      in
      Logs.info (fun log ->
          log "Setting up hook for job %s: %d\n" job_id serial_id)
  | None -> Logs.debug (fun log -> log "Job already stopped: %s\n" job_id)

let get_job_id x =
  Current.with_context x (fun () ->
      let open Current.Syntax in
      let+ md = Current.Analysis.metadata x in
      match md with
      | Some { Current.Metadata.job_id; _ } -> job_id
      | None -> None)

let record_pipeline_stage ~serial_id ~conninfo image job_id =
  let+ job_id and+ state = Current.state ~hidden:true image in
  match (job_id, state) with
  | Some job_id, Error (`Active _) ->
      (* NOTE: For some reason this hook gets called twice, even if we match for
         (`Active `Running), explicitly. The DB calls would happen twice, which
         shouldn't be a problem.*)
      setup_on_cancel_hook ~job_id ~serial_id ~conninfo;
      Storage.record_stage_start ~job_id ~serial_id ~conninfo;
      "recorded stage start"
  | Some job_id, Error (`Msg m) ->
      Logs.err (fun log -> log "Error for job %s: \n%s\n" job_id m);
      Storage.record_stage_failure ~serial_id ~reason:m ~conninfo;
      "*RECORDED FAILURE*"
  | _ -> "(no error)"

module Env = Custom_dockerfile.Env

let pipeline ~config ~ocluster ~conninfo ~repository env =
  let worker = env.Env.worker in
  let docker_image = env.Env.image in
  let key = Config.key_of_repo ~config repository worker docker_image in
  let serial_id =
    Storage.setup_metadata ~repository ~conninfo ~worker ~docker_image
  in
  let docker_options =
    {
      Cluster_api.Docker.Spec.defaults with
      build_args = env.Custom_dockerfile.Env.build_args;
    }
  in
  let dockerfile =
    match env.Env.dockerfile with
    | `Contents d -> `Contents (Current.map Dockerfile.string_of_t d)
    | `File filename -> `Path (Fpath.to_string filename)
  in
  let src =
    let commit = Repository.commit repository in
    if Repository.info repository <> "local/local"
    then commit
    else
      let open Current_git.Commit_id in
      v ~repo:"git://pipeline/" ~gref:(gref commit) ~hash:(hash commit)
  in
  let ocluster_worker =
    Current_ocluster.build ~pool:worker
      ~src:(Current.return [ src ])
      ~options:docker_options ocluster dockerfile
  in
  let worker_job_id = get_job_id ocluster_worker in
  let output =
    Json_stream.save ~config ~conninfo ~repository ~serial_id ~worker
      ~docker_image worker_job_id
  in
  let+ () =
    Config.slack_log ~config ~key:(key ^ " worker_job_id")
    @@ record_pipeline_stage ~serial_id ~conninfo ocluster_worker worker_job_id
  and+ () =
    Config.slack_log ~config ~key:(key ^ " record_stage_failure")
    @@ Current.map (function
         | Error (`Msg m) ->
             let stage = "json_stream_save" in
             Logs.err (fun log -> log "Error in %s stage: %s\n\n" stage m);
             Storage.record_stage_failure ~serial_id ~reason:m ~conninfo;
             "error recorded!"
         | _ -> "(no error)")
    @@ Current.catch output
  and+ () =
    Config.slack_log ~config ~key:(key ^ " worker")
    @@ Current.map (fun () -> "(ok)")
    @@ ocluster_worker
  and+ () = Config.slack_log ~config ~key:(key ^ " jsons") @@ output in
  ()

let pipeline ~config ~ocluster ~conninfo ~repository =
  Current.list_iter
    (module Custom_dockerfile.Env)
    (fun env ->
      let* env in
      if Benchmark.Db.exists ~conninfo ~env repository
      then Current.return ()
      else pipeline ~config ~ocluster ~conninfo ~repository env)
    (Custom_dockerfile.dockerfiles ~config ~repository)

let pipeline ~config ~ocluster ~conninfo repository =
  let p = pipeline ~config ~ocluster ~conninfo ~repository in
  let* () = p |> github_set_status ~repository in
  Current.ignore_value p

let github_repositories repo =
  let* refs =
    Current.component "Get PRs"
    |> let> api, repo = repo in
       Github.Api.refs api repo
  in
  let* refs_with_title =
    Current.component "Get refs with title"
    |> let> api, repo = repo in
       Refs.refs api repo
  in
  let default_branch = Github.Api.default_ref refs in
  let default_branch_name = Util.get_branch_name default_branch in
  let ref_map = Github.Api.all_refs refs in
  let title_map = refs_with_title in
  let+ api, repo = repo in
  let repository =
    Repository.v ~name:repo.name ~owner:repo.owner ~github_api:api
  in
  Github.Api.Ref_map.fold
    (fun key head lst ->
      let title =
        try Github.Api.Ref_map.find key title_map with Not_found -> None
      in
      let commit = Github.Api.Commit.id head in
      let message = Github.Api.Commit.message head in
      let repository =
        repository ~commit ~github_head:head ~commit_message:message ?title
      in
      match key with
      (* Skip all branches other than the default branch, and check PRs *)
      | `Ref branch when branch = default_branch ->
          repository ~branch:default_branch_name () :: lst
      | `Ref _ -> lst
      | `PR pull_number -> repository ~pull_number () :: lst)
    ref_map []

let filter_stale_repositories repos =
  let stale_timestamp = Util.stale_timestamp () in
  List.filter_map
    (fun repo ->
      let head = Repository.github_head repo in
      (* If commit is more than two weeks old, then skip it.*)
      match head with
      | Some head when Github.Api.Commit.committed_date head > stale_timestamp
        ->
          Some repo
      | None when Repository.info repo = "local/local" -> Some repo
      | _ -> None)
    repos

let repositories = function
  | Source.Local path ->
      let local = Git.Local.v path in
      let src = Git.Local.head_commit local in
      let+ head = Git.Local.head local and+ commit = src >>| Git.Commit.id in
      let branch =
        match head with
        | `Commit _ -> None
        | `Ref git_ref -> (
            match String.split_on_char '/' git_ref with
            | [ _; _; branch ] -> Some branch
            | _ ->
                Logs.warn (fun log ->
                    log "Could not extract branch name from: %s" git_ref);
                None)
      in
      [ Repository.v ?branch ~src ~commit ~name:"local" ~owner:"local" () ]
  | Github { repo; token; webhook_secret } ->
      let token = token |> Util.read_fpath |> String.trim in
      let api = Current_github.Api.of_oauth ~token ~webhook_secret in
      let repo = Current.return (api, repo) in
      github_repositories repo
  | Github_app app ->
      let+ repos =
        Github.App.installations app
        |> Current.list_map (module Github.Installation) @@ fun installation ->
           let repos = Github.Installation.repositories installation in
           repos
           |> Current.list_map ~collapse_key:"repo"
                (module Github.Api.Repo)
                github_repositories
      in
      List.concat (List.concat repos)

let repositories sources =
  let repos = Current.list_seq (List.map repositories sources) in
  Current.map List.concat repos

let string_of_repositories repos =
  String.concat ", "
  @@ List.sort String.compare
  @@ List.map (fun r -> Repository.to_string r) repos

let pull_requests_from_repositories repos =
  List.filter_map
    (fun r ->
      match Repository.pull_number r with
      | None -> None
      | Some pull_number -> Some (Repository.info r, pull_number))
    repos

let process_pipeline ~config ~ocluster ~conninfo ~sources () =
  let repos = repositories sources in
  let fresh_repos = Current.map filter_stale_repositories repos in
  let+ () =
    let+ open_pulls = Current.map pull_requests_from_repositories repos in
    Storage.mark_closed_pull_requests ~open_pulls ~conninfo
  and+ () =
    Config.slack_log ~config ~key:"*repositories outcome*"
    @@ Current.map (fun () -> "ALL GOOD")
    @@ Current.list_iter ~collapse_key:"pipeline"
         (module Repository)
         (fun repo ->
           let* repo in
           pipeline ~config ~ocluster ~conninfo repo)
         fresh_repos
  and+ () =
    Config.slack_log ~config ~key:"*repositories*"
      (Current.map string_of_repositories fresh_repos)
  in
  ()

let v ~config ~server:mode ~sources conninfo () =
  Db_util.check_connection ~conninfo;
  let cap_path = "/app/submission.cap" in
  let vat = Capnp_rpc_unix.client_only_vat () in
  let sr =
    match Capnp_rpc_unix.Cap_file.load vat cap_path with
    | Error (`Msg msg) -> failwith msg
    | Ok sr -> sr
  in
  let ocluster = Current_ocluster.(v (Connection.create sr)) in
  let pipeline = process_pipeline ~config ~ocluster ~conninfo ~sources in
  let engine = Current.Engine.create pipeline in
  let webhook =
    match List.find_map Source.webhook_secret sources with
    | None -> []
    | Some webhook_secret ->
        let webhook =
          Github.webhook ~engine ~webhook_secret
            ~has_role:Current_web.Site.allow_all
        in
        [ Routes.((s "webhooks" / s "github" /? nil) @--> webhook) ]
  in
  let metrics_routes =
    [
      Routes.(
        (s "benchmarks" / s "metrics" /? nil)
        @--> Api.capture_metrics conninfo config.api_tokens);
    ]
  in
  let routes = metrics_routes @ webhook @ Current_web.routes engine in
  let site =
    Current_web.Site.(v ~has_role:allow_all) ~name:"Benchmarks" routes
  in
  Logging.run
    (Lwt.choose [ Current.Engine.thread engine; Current_web.run ~mode site ])
