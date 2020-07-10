open Current.Syntax
module Git = Current_git
module Github = Current_github
module Docker = Current_docker.Default
module Slack = Current_slack

let pool = Current.Pool.create ~label:"docker" 1

let read_channel_uri p =
  Utils.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

(* Generate a Dockerfile for building all the opam packages in the build context. *)
let dockerfile ~base =
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run
       "sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
        liblmdb-dev m4 pkg-config gnuplot-x11"
  @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"index" ()
  @@ workdir "index"
  @@ run "opam install -y --deps-only -t ."
  @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
  @@ run "opam config exec -- dune build @@default bench/bench.exe"
  @@ run "eval $(opam env)"

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 1) ()

let pipeline ?slack_path ~conninfo ~pr_num ~head ~name ~dockerfile ~tmpfs
    ~docker_cpuset_cpus ~docker_cpuset_mems =
  let s =
    let run_args =
      [ "--security-opt"; "seccomp=./aslr_seccomp.json" ]
      @ tmpfs
      @ docker_cpuset_cpus
      @ docker_cpuset_mems
    in
    let+ output =
      let src =
        Git.fetch (Current.map Github.Api.Commit.id (Current.return head))
      in
      let image = Docker.build ~pool ~pull:false ~dockerfile (`Git src) in
      Docker.pread ~run_args image
        ~args:
          [
            "/usr/bin/setarch";
            "x86_64";
            "--addr-no-randomize";
            "_build/default/bench/bench.exe";
            "--nb-entries";
            "1000";
            "-d";
            "/dev/shm";
            "--json";
          ]
    in
    let commit = Github.Api.Commit.hash head in
    let content =
      Utils.merge_json name commit (Yojson.Basic.from_string output)
    in
    let () = Utils.populate_postgres conninfo commit content pr_num in
    match slack_path with Some p -> Some (p, content) | None -> None
  in
  s
  |> Current.option_map (fun p ->
         Current.component "post"
         |> let** path, _ = p in
            let channel = read_channel_uri path in
            Slack.post channel ~key:"output" (Current.map snd p))
  |> Current.ignore_value

let process_pipeline ?slack_path ?docker_cpu ?docker_numa_node ~docker_shm_size
    ~conninfo ~github ~(repo : Github.Repo_id.t) () =
  let name = repo.name in
  let dockerfile =
    let+ base = Docker.pull ~schedule:weekly "ocaml/opam2" in
    `Contents (dockerfile ~base)
  in
  let docker_cpuset_cpus =
    match docker_cpu with
    | Some i -> [ "--cpuset-cpus"; string_of_int i ]
    | None -> []
  in
  let docker_cpuset_mems =
    match docker_numa_node with
    | Some i -> [ "--cpuset-mems"; string_of_int i ]
    | None -> []
  in
  let tmpfs =
    match docker_numa_node with
    | Some i ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d"
            docker_shm_size i;
        ]
    | None ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" docker_shm_size;
        ]
  in
  let repo = Current.return (github, repo) in
  let* refs =
    Current.component "Get PRs"
    |> let> api, repo = repo in
       Github.Api.refs api repo
  in
  Github.Api.Ref_map.fold
    (fun key head _ ->
      match key with
      | `Ref _ -> Current.return () (* Skip branches, only check PRs *)
      | `PR pr_num ->
          pipeline ?slack_path ~conninfo ~pr_num ~head ~name ~dockerfile ~tmpfs
            ~docker_cpuset_cpus ~docker_cpuset_mems)
    refs (Current.return ())

let webhooks = [ ("github", Github.webhook) ]

type token = { token_file : string; token_api_file : Github.Api.t }

let main config mode github_token repo slack_path docker_cpu docker_numa_node
    docker_shm_size conninfo () =
  let github = github_token.token_api_file in
  let engine =
    Current.Engine.create ~config
      (process_pipeline ?slack_path ?docker_cpu ?docker_numa_node
         ~docker_shm_size ~conninfo ~github ~repo)
  in
  let routes =
    Routes.((s "webhooks" / s "github" /? nil) @--> Github.webhook)
    :: Current_web.routes engine
  in
  let site =
    Current_web.Site.(v ~has_role:allow_all) ~name:"Benchmarks" routes
  in
  Logging.run
    (Lwt.choose [ Current.Engine.thread engine; Current_web.run ~mode site ])

(* Command-line parsing *)

open Cmdliner

let path = Arg.conv ~docv:"PATH" Fpath.(of_string, pp)

let slack_path =
  let doc =
    "File containing the Slack endpoint URI to use for result notifications."
  in
  Arg.(value & opt (some path) None & info [ "s"; "slack" ] ~doc)

let docker_cpu =
  let doc = "CPU/core that should run the benchmarks." in
  Arg.(value & opt (some int) None & info [ "docker-cpu" ] ~doc)

let docker_numa_node =
  let doc =
    "NUMA node to use for memory and tmpfs storage (should match CPU core if \
     enabled, see `lscpu`)"
  in
  Arg.(value & opt (some int) None & info [ "docker-numa-node" ] ~doc)

let docker_shm_size =
  let doc = "Size of tmpfs volume to be mounted in /dev/shm (in GB)." in
  Arg.(value & opt int 4 & info [ "docker-shm-size" ] ~doc)

let repo =
  Arg.required
  @@ Arg.pos 0 (Arg.some Github.Repo_id.cmdliner) None
  @@ Arg.info ~doc:"The GitHub repository (owner/name) to monitor." ~docv:"REPO"
       []

let setup_log =
  let init style_renderer level = Logging.init ?style_renderer ?level () in
  Term.(const init $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let token_file =
  Arg.required
  @@ Arg.opt Arg.(some file) None
  @@ Arg.info ~doc:"A file containing the GitHub OAuth token." ~docv:"PATH"
       [ "github-token-file" ]

let conninfo =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"Connection info for Postgres DB" ~docv:"PATH"
       [ "conn-info" ]

let make_config token_file =
  {
    token_file;
    token_api_file =
      Github.Api.of_oauth @@ String.trim (Utils.read_file token_file);
  }

let git_cmdliner = Term.(const make_config $ token_file)

let cmd =
  let doc = "Monitor a GitHub repository." in
  ( Term.(
      const main
      $ Current.Config.cmdliner
      $ Current_web.cmdliner
      $ git_cmdliner
      $ repo
      $ slack_path
      $ docker_cpu
      $ docker_numa_node
      $ docker_shm_size
      $ conninfo
      $ setup_log),
    Term.info "github" ~doc )

let () = Term.(exit @@ eval cmd)
