open Current.Syntax
module Git = Current_git
module Github = Current_github
module Docker = Current_docker.Default
module Docker_util = Current_util.Docker_util
module Slack = Current_slack
module Logging = Logging
module Benchmark = Models.Benchmark

let ( >>| ) x f = Current.map f x

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
end

let pool = Current.Pool.create ~label:"docker" 1

let read_channel_uri p =
  Util.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

(* Generate a Dockerfile for building all the opam packages in the build context. *)
let dockerfile ~base ~repository =
  let opam_dependencies =
    (* FIXME: This should be supported by a custom Dockerfiles. *)
    if String.equal repository "dune" then
      "opam install ./dune-bench.opam -y --deps-only  -t"
    else "opam install -y --deps-only -t ."
  in
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run
       "sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
        liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev \
        libpcre3-dev"
  @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"bench-dir" ()
  @@ workdir "bench-dir"
  @@ run "opam remote add origin https://opam.ocaml.org"
  @@ run "%s" opam_dependencies
  @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
  @@ run "eval $(opam env)"

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 1) ()

let frontend_url = Sys.getenv "OCAML_BENCH_FRONTEND_URL"

(* $server/$repo_owner/$repo_name/pull/$pull_number *)
let make_commit_status_url owner repository pull_number =
  let uri_end =
    match pull_number with
    | None -> "/" ^ owner ^ "/" ^ repository
    | Some number ->
        "/" ^ owner ^ "/" ^ repository ^ "/pull/" ^ string_of_int number
  in
  Uri.of_string (frontend_url ^ uri_end)

let github_status_of_state url = function
  | Ok _ -> Github.Api.Status.v ~url `Success ~description:"Passed"
  | Error (`Active _) -> Github.Api.Status.v ~url `Pending
  | Error (`Msg m) -> Github.Api.Status.v ~url `Failure ~description:m

let pipeline ~slack_path ~conninfo ?branch ?pull_number ~dockerfile ~tmpfs
    ~docker_cpuset_cpus ~docker_cpuset_mems ~head ~repository ~owner () =
  let repo_id = (owner, repository) in
  let src =
    match head with
    | `Github api_commit ->
        Git.fetch (Current.map Github.Api.Commit.id (Current.return api_commit))
    | `Local commit -> commit
  in
  let current_image = Docker.build ~pool ~pull:false ~dockerfile (`Git src) in
  let s =
    let run_args =
      [
        "--security-opt";
        "seccomp=./aslr_seccomp.json";
        "--mount";
        "type=volume,src=current-bench-data,dst=/home/opam/bench-dir/current-bench-data";
      ]
      @ tmpfs
      @ docker_cpuset_cpus
      @ docker_cpuset_mems
    in
    let run_at = Ptime_clock.now () in
    let* commit =
      match head with
      | `Github api_commit -> Current.return (Github.Api.Commit.hash api_commit)
      | `Local commit -> commit >>| Git.Commit.hash
    in
    let repo_info = owner ^ "/" ^ repository in
    let current_output =
      Docker_util.pread_log ~pool ~run_args current_image ~repo_info
        ?pull_number ?branch ~commit
        ~args:
          [
            "/usr/bin/setarch"; "x86_64"; "--addr-no-randomize"; "make"; "bench";
          ]
    in
    let+ build_job_id = Current_util.get_job_id current_image
    and+ run_job_id = Current_util.get_job_id current_output
    and+ output = current_output in
    let duration = Ptime.diff (Ptime_clock.now ()) run_at in
    Logs.debug (fun log -> log "Benchmark output:\n%s" output);
    let () =
      let db = new Postgresql.connection ~conninfo () in
      output
      |> Json_util.parse_many
      |> List.iter (fun output_json ->
             let benchmark_name =
               Yojson.Safe.Util.(member "name" output_json)
               |> Yojson.Safe.Util.to_string_option
             in
             Yojson.Safe.Util.(member "results" output_json)
             |> Yojson.Safe.Util.to_list
             |> List.map
                  (Benchmark.make ~duration ~run_at ~repo_id ~benchmark_name
                     ~commit ?pull_number ?build_job_id ?run_job_id ?branch)
             |> List.iter (Models.Benchmark.Db.insert db));
      db#finish
    in
    match slack_path with Some p -> Some (p, output) | None -> None
  in
  s
  |> Current.option_map (fun p ->
         Current.component "post"
         |> let** path, _ = p in
            let channel = read_channel_uri path in
            let output = Current.map snd p in
            Slack.post channel ~key:"output" output)
  |> Current.state
  |> fun result ->
  match head with
  | `Local _ -> Current.ignore_value result
  | `Github head ->
      let status_url = make_commit_status_url owner repository pull_number in
      result
      >>| github_status_of_state status_url
      |> Github.Api.Commit.set_status (Current.return head) "ocaml-benchmarks"
      |> Current.ignore_value

let process_pipeline ~(docker_config : Docker_config.t) ~conninfo
    ~(source : Source.t) () =
  let docker_cpuset_cpus =
    match docker_config.cpu with
    | Some cpu -> [ "--cpuset-cpus"; cpu ]
    | None -> []
  in
  let docker_cpuset_mems =
    match docker_config.numa_node with
    | Some i -> [ "--cpuset-mems"; string_of_int i ]
    | None -> []
  in
  let tmpfs =
    match docker_config.numa_node with
    | Some i ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d"
            docker_config.shm_size i;
        ]
    | None ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" docker_config.shm_size;
        ]
  in
  let pipeline =
    pipeline ~conninfo ~tmpfs ~docker_cpuset_cpus ~docker_cpuset_mems
  in
  match source with
  | Github { repo; slack_path; token } ->
      let dockerfile =
        let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
        `Contents (dockerfile ~base ~repository:repo.name)
      in
      let pipeline =
        pipeline ~slack_path ~dockerfile ~repository:repo.name ~owner:repo.owner
      in
      let* refs =
        let api =
          token |> Util.read_fpath |> String.trim |> Current_github.Api.of_oauth
        in
        let repo = Current.return (api, repo) in
        Current.component "Get PRs"
        |> let> api, repo = repo in
           Github.Api.refs api repo
      in
      let default_branch = Github.Api.default_ref refs in
      let default_branch_name = Util.get_branch_name default_branch in
      let ref_map = Github.Api.all_refs refs in
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
  | Local path ->
      let dockerfile =
        let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
        `Contents (dockerfile ~base ~repository:"local")
      in
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
      pipeline ?branch ~dockerfile ~head:head_commit ~repository:"local"
        ~owner:"local" ~slack_path:None ()
  | Github_app app ->
      Github.App.installations app
      |> Current.list_iter (module Github.Installation) @@ fun installation ->
         let repos = Github.Installation.repositories installation in
         repos
         |> Current.list_iter ~collapse_key:"repo" (module Github.Api.Repo)
            @@ fun repo ->
            let* refs =
              Current.component "Get PRS"
              |> let> api, repo = repo in
                 Github.Api.refs api repo
            in
            let ref_map = Github.Api.all_refs refs in
            let default_branch = Github.Api.default_ref refs in
            let default_branch_name = Util.get_branch_name default_branch in
            let* _, repo = repo in
            let dockerfile =
              let+ base = Docker.pull ~schedule:weekly "ocaml/opam" in
              `Contents (dockerfile ~base ~repository:repo.name)
            in
            let pipeline =
              pipeline ~dockerfile ~slack_path:None ~repository:repo.name
                ~owner:repo.owner
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
