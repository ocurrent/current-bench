open Cmdliner

let path = Arg.conv ~docv:"PATH" Fpath.(of_string, pp)

module Source = struct
  let github =
    let repo =
      Arg.required
      @@ Arg.pos 0 (Arg.some Current_github.Repo_id.cmdliner) None
      @@ Arg.info ~doc:"The GitHub repository (owner/name) to monitor."
           ~docv:"REPO" []
    in
    let github_token_path =
      Arg.required
      @@ Arg.opt Arg.(some path) None
      @@ Arg.info ~doc:"A file containing the GitHub OAuth token." ~docv:"PATH"
           [ "github-token-file" ]
    in
    let slack_path =
      let doc =
        "File containing the Slack endpoint URI to use for result \
         notifications."
      in
      Arg.(value & opt (some path) None & info [ "s"; "slack" ] ~doc)
    in
    Term.(
      const (fun repo token slack_path ->
          Pipeline.Source.github ~repo ~token ~slack_path)
      $ repo
      $ github_token_path
      $ slack_path)

  let local =
    let path =
      Arg.required
      @@ Arg.pos 0 (Arg.some path) None
      @@ Arg.info ~doc:"Path to a Git repository on disk" ~docv:"PATH" []
    in
    Term.(const Pipeline.Source.local $ path)

  let github_app =
    Term.(const Pipeline.Source.github_app $ Current_github.App.cmdliner)
end

module Docker = struct
  let cpu =
    let doc = "CPU/core that should run the benchmarks." in
    Arg.(value & opt (some int) None & info [ "docker-cpu" ] ~doc)

  let numa_node =
    let doc =
      "NUMA node to use for memory and tmpfs storage (should match CPU core if \
       enabled, see `lscpu`)"
    in
    Arg.(value & opt (some int) None & info [ "docker-numa-node" ] ~doc)

  let shm_size =
    let doc = "Size of tmpfs volume to be mounted in /dev/shm (in GB)." in
    Arg.(value & opt int 4 & info [ "docker-shm-size" ] ~doc)

  let v =
    Term.(
      const (fun cpu numa_node shm_size ->
          Pipeline.Docker_config.v ?cpu ?numa_node ~shm_size)
      $ cpu
      $ numa_node
      $ shm_size)
end

let setup_log =
  let init style_renderer level =
    Pipeline.Logging.init ?style_renderer ?level ()
  in
  Term.(const init $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let conninfo =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"Connection info for Postgres DB" ~docv:"PATH"
       [ "conn-info" ]

let cmd : (Pipeline.Source.t -> (unit, [ `Msg of string ]) result) Term.t =
  Term.(
    const (fun current_config server docker_config conninfo () source ->
        Pipeline.v ~current_config ~docker_config ~server ~source conninfo ())
    $ Current.Config.cmdliner
    $ Current_web.cmdliner
    $ Docker.v
    $ conninfo
    $ setup_log)

let () =
  let default =
    let default_info =
      let doc = "Continuously benchmark a Git repository." in
      Term.info ~doc "pipeline"
    in
    Term.(ret (const (`Help (`Auto, None))), default_info)
  in
  Term.(
    exit
    @@ eval_choice default
         [
           ( cmd $ Source.local,
             Term.info ~doc:"Monitor a Git repository on disk." "local" );
           ( cmd $ Source.github,
             Term.info ~doc:"Monitor a remote GitHub repository." "github" );
           ( cmd $ Source.github_app,
             Term.info
               ~doc:"Monitor all repositories associated with github_app."
               "github_app" );
         ])
