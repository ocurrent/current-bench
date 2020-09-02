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
  @@ Arg.pos 0 (Arg.some Current_github.Repo_id.cmdliner) None
  @@ Arg.info ~doc:"The GitHub repository (owner/name) to monitor." ~docv:"REPO"
       []

let setup_log =
  let init style_renderer level =
    Pipeline.Logging.init ?style_renderer ?level ()
  in
  Term.(const init $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let github_token_path =
  Arg.required
  @@ Arg.opt Arg.(some path) None
  @@ Arg.info ~doc:"A file containing the GitHub OAuth token." ~docv:"PATH"
       [ "github-token-file" ]

let conninfo =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"Connection info for Postgres DB" ~docv:"PATH"
       [ "conn-info" ]

let cmd =
  let doc = "Monitor a GitHub repository." in
  ( Term.(
      const
        (fun
          config
          server
          repo
          github_token
          slack_path
          docker_cpu
          docker_numa_node
          docker_shm_size
          conninfo
          ()
        ->
          Pipeline.v ~config ~server ~repo ~github_token ?slack_path ?docker_cpu
            ?docker_numa_node ~docker_shm_size conninfo)
      $ Current.Config.cmdliner
      $ Current_web.cmdliner
      $ repo
      $ github_token_path
      $ slack_path
      $ docker_cpu
      $ docker_numa_node
      $ docker_shm_size
      $ conninfo
      $ setup_log),
    Term.info "github" ~doc )

let () = Term.(exit @@ eval cmd)
