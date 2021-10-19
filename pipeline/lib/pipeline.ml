open Current.Syntax
module Git = Current_git
module Github = Current_github
module Docker = Current_docker.Default
module Docker_util = Current_util.Docker_util
module Slack = Current_slack
module Logging = Logging
module Benchmark = Models.Benchmark

let ( >>| ) x f = Current.map f x

let get_benchmark_name json =
  json |> Yojson.Safe.Util.(member "name") |> Yojson.Safe.Util.to_string_option

let get_result_list json =
  json |> Yojson.Safe.Util.(member "results") |> Yojson.Safe.Util.to_list

let validate_json json_list =
  let tbl = Hashtbl.create 1000 in
  List.iter
    (fun json ->
      let benchmark_name = get_benchmark_name json in
      match Hashtbl.find_opt tbl benchmark_name with
      | Some _ ->
          raise
          @@ Failure
               "This benchmark name already exists, please create a unique name"
      | None ->
          let results = get_result_list json in
          Hashtbl.add tbl benchmark_name results)
    json_list;
  tbl

module Source = struct
  type github = {
    token : Fpath.t;
    slack_path : Fpath.t option;
    repo : Github.Repo_id.t;
  }

  type t = Github of github | Local of Fpath.t | Github_app of Github.App.t

  let github ~token ~slack_path ~repo = Github { token; slack_path; repo }

  let local path = Local path

  let github_app t = Github_app t
end

module Docker_config = struct
  type t = { cpu : string option; numa_node : int option; shm_size : int }

  let v ?cpu ?numa_node ~shm_size () = { cpu; numa_node; shm_size }

  let cpuset_cpus t =
    match t.cpu with Some cpu -> [ "--cpuset-cpus"; cpu ] | None -> []

  let cpuset_mems t =
    match t.numa_node with
    | Some i -> [ "--cpuset-mems"; string_of_int i ]
    | None -> []

  let tmpfs t =
    match t.numa_node with
    | Some i ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d" t.shm_size i;
        ]
    | None ->
        [ "--tmpfs"; Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" t.shm_size ]

  let run_args t =
    [
      "--security-opt";
      "seccomp=./aslr_seccomp.json";
      "--mount";
      "type=volume,src=current-bench-data,dst=/home/opam/bench-dir/current-bench-data";
    ]
    @ tmpfs t
    @ cpuset_cpus t
    @ cpuset_mems t
end

let pool = Current.Pool.create ~label:"docker" 1

let read_channel_uri p =
  Util.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

let github_status_of_state url = function
  | Ok _ -> Github.Api.Status.v ~url `Success ~description:"Passed"
  | Error (`Active _) -> Github.Api.Status.v ~url `Pending
  | Error (`Msg m) -> Github.Api.Status.v ~url `Failure ~description:m

let github_set_status ~repository head result =
  match head with
  | `Local _ -> Current.ignore_value result
  | `Github head ->
      let status_url = Repository.commit_status_url repository in
      result
      >>| github_status_of_state status_url
      |> Github.Api.Commit.set_status (Current.return head) "ocaml-benchmarks"
      |> Current.ignore_value

let slack_post ~repository (output : string Current.t) =
  match Repository.slack_path repository with
  | None -> Current.ignore_value output
  | Some path ->
      Current.component "slack post"
      |> let** _ = output in
         let channel = read_channel_uri path in
         Slack.post channel ~key:"output" output

let db_save ~conninfo benchmark output =
  let db = new Postgresql.connection ~conninfo () in
  output
  |> Json_util.parse_many
  |> validate_json
  |> Hashtbl.iter (fun benchmark_name results ->
         results
         |> List.map (benchmark ~benchmark_name)
         |> List.iter (Models.Benchmark.Db.insert db));
  db#finish

let docker_make_bench ~run_args ~repository ~commit image =
  let { Repository.branch; pull_number; _ } = repository in
  let repo_info = Repository.info repository in
  Docker_util.pread_log ~pool ~run_args image ~repo_info ?pull_number ?branch
    ~commit
    ~args:
      [
        "/usr/bin/setarch";
        "x86_64";
        "--addr-no-randomize";
        "sh";
        "-c";
        "eval $(opam env) && make bench";
      ]

let pipeline ~conninfo ~run_args ~repository ~commit =
  let src = Repository.src repository in
  let dockerfile = Custom_dockerfile.dockerfile ~pool ~run_args ~repository in
  let current_image = Docker.build ~pool ~pull:false ~dockerfile (`Git src) in
  let run_at = Ptime_clock.now () in
  let current_output =
    docker_make_bench ~run_args ~repository ~commit current_image
  in
  let+ build_job_id = Current_util.get_job_id current_image
  and+ run_job_id = Current_util.get_job_id current_output
  and+ output = current_output in
  let duration = Ptime.diff (Ptime_clock.now ()) run_at in
  Logs.debug (fun log -> log "Benchmark output:\n%s" output);
  let () =
    db_save ~conninfo
      (Benchmark.make ~duration ~run_at ~repository ~commit ?build_job_id
         ?run_job_id)
      output
  in
  output

let fetch = function
  | `Github api_commit ->
      Git.fetch (Current.return (Github.Api.Commit.id api_commit))
  | `Local commit -> commit

let pipeline ~conninfo ~run_args ?slack_path ?branch ?pull_number ~head
    ~repository ~owner () =
  let repository =
    {
      Repository.owner;
      name = repository;
      src = fetch head;
      pull_number;
      branch;
      slack_path;
    }
  in
  let* commit =
    match head with
    | `Github api_commit -> Current.return (Github.Api.Commit.hash api_commit)
    | `Local commit -> commit >>| Git.Commit.hash
  in
  pipeline ~conninfo ~run_args ~repository ~commit
  |> slack_post ~repository
  |> Current.state
  |> github_set_status ~repository head

let github_pipeline ~conninfo ~run_args ?slack_path repo =
  let pipeline = pipeline ~conninfo ~run_args in
  let* refs =
    Current.component "Get PRs"
    |> let> api, repo = repo in
       Github.Api.refs api repo
  in
  let default_branch = Github.Api.default_ref refs in
  let default_branch_name = Util.get_branch_name default_branch in
  let ref_map = Github.Api.all_refs refs in
  let* _, repo = repo in
  let pipeline =
    pipeline ?slack_path ~repository:repo.name ~owner:repo.owner
  in
  Github.Api.Ref_map.fold
    (fun key head _ ->
      let head = `Github head in
      match key with
      | `Ref branch ->
          if branch = default_branch then
            pipeline ~head ~branch:default_branch_name ()
          else Current.return ()
      | `PR pull_number -> pipeline ~head ~pull_number ()
      (* Skip all branches other than master, and check PRs *))
    ref_map (Current.return ())

let process_pipeline ~(docker_config : Docker_config.t) ~conninfo
    ~(source : Source.t) () =
  let run_args = Docker_config.run_args docker_config in
  match source with
  | Github { repo; slack_path; token } ->
      let api =
        token |> Util.read_fpath |> String.trim |> Current_github.Api.of_oauth
      in
      let repo = Current.return (api, repo) in
      github_pipeline ~conninfo ~run_args ?slack_path repo
  | Local path ->
      let local = Git.Local.v path in
      let* head = Git.Local.head local in
      let head_commit = `Local (Git.Local.head_commit local) in
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
      pipeline ~conninfo ~run_args
        ?branch ~head:head_commit ~repository:"local" ~owner:"local" ()
  | Github_app app ->
      Github.App.installations app
      |> Current.list_iter (module Github.Installation) @@ fun installation ->
         let repos = Github.Installation.repositories installation in
         repos
         |> Current.list_iter ~collapse_key:"repo" (module Github.Api.Repo)
            @@ fun repo ->
                 github_pipeline ~conninfo ~run_args repo

let v ~current_config ~docker_config ~server:mode ~(source : Source.t) conninfo
    () =
  Db_util.check_connection ~conninfo;
  let pipeline = process_pipeline ~docker_config ~conninfo ~source in
  let engine = Current.Engine.create ~config:current_config pipeline in
  let routes =
    Routes.((s "webhooks" / s "github" /? nil) @--> Github.webhook)
    :: Current_web.routes engine
  in
  let site =
    Current_web.Site.(v ~has_role:allow_all) ~name:"Benchmarks" routes
  in
  Logging.run
    (Lwt.choose [ Current.Engine.thread engine; Current_web.run ~mode site ])
