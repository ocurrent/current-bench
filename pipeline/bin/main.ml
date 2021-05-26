open Cmdliner

let path = Arg.conv ~docv:"PATH" Fpath.(of_string, pp)

module Github = struct
  let repo =
    Arg.required
    @@ Arg.pos 0 (Arg.some Current_github.Repo_id.cmdliner) None
    @@ Arg.info ~doc:"The GitHub repository (owner/name) to monitor."
         ~docv:"REPO" []

  let github_token_path =
    Arg.required
    @@ Arg.opt Arg.(some path) None
    @@ Arg.info ~doc:"A file containing the GitHub OAuth token." ~docv:"PATH"
         [ "github-token-file" ]

  let cmd =
    Term.(
      const (fun repo token -> Pipeline.Source.github ~repo ~token)
      $ repo
      $ github_token_path)
end

module Github_app = struct
  let cmd =
    Term.(const Pipeline.Source.github_app $ Current_github.App.cmdliner)
end

module Local = struct
  let cmd =
    let path =
      Arg.required
      @@ Arg.pos 0 (Arg.some path) None
      @@ Arg.info ~doc:"Path to a Git repository on disk" ~docv:"PATH" []
    in
    Term.(const Pipeline.Source.local $ path)
end

module Slack = struct
  let path =
    let doc =
      "File containing the Slack endpoint URI to use for result notifications."
    in
    Arg.(value & opt (some path) None & info [ "s"; "slack" ] ~doc)

  let config =
    Term.(const (fun path -> Pipeline.Config.Slack.make ?path ()) $ path)
end

module Docker = struct
  let cpuset_cpus =
    let doc =
      "CPU/core that should run the benchmarks. A comma-separated list or \
       hyphen-separated range of CPUs a container can use, if you have more \
       than one CPU"
    in
    Arg.(value & opt (some string) None & info [ "docker-cpu" ] ~doc)

  let numa_node =
    let doc =
      "NUMA node to use for memory and tmpfs storage (should match CPU core if \
       enabled, see `lscpu`)"
    in
    Arg.(value & opt (some int) None & info [ "docker-numa-node" ] ~doc)

  let shm_size =
    let doc = "Size of tmpfs volume to be mounted in /dev/shm (in GB)." in
    Arg.(value & opt int 4 & info [ "docker-shm-size" ] ~doc)

  let config =
    Term.(
      const (fun cpuset_cpus numa_node shm_size ->
          Pipeline.Config.Docker.make ?cpuset_cpus ?numa_node ~shm_size ())
      $ cpuset_cpus
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
    const
      (fun current_config server docker_config slack_config conninfo () source
      ->
        Pipeline.v ~current_config ~docker_config ~slack_config ~server ~source
          conninfo ())
    $ Current.Config.cmdliner
    $ Current_web.cmdliner
    $ Docker.config
    $ Slack.config
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
           ( cmd $ Local.cmd,
             Term.info ~doc:"Monitor a Git repository on disk." "local" );
           ( cmd $ Github.cmd,
             Term.info ~doc:"Monitor a remote GitHub repository." "github" );
           ( cmd $ Github_app.cmd,
             Term.info
               ~doc:"Monitor all repositories associated with github_app."
               "github_app" );
         ])
