open Cmdliner

let path = Arg.conv ~docv:"PATH" Fpath.(of_string, pp)

let uri =
  let of_string str = Ok (Uri.of_string str) in
  Arg.conv ~docv:"PATH" (of_string, Uri.pp)

module Cmd = struct
  let local =
    let path =
      Arg.required
      @@ Arg.pos 0 (Arg.some path) None
      @@ Arg.info ~doc:"Path to a Git repository on disk" ~docv:"PATH" []
    in
    Term.(const Pipeline.Source.local $ path)

  let github_app =
    Term.(const Pipeline.Source.github_app $ Current_github.App.cmdliner)

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

  let github =
    Term.(
      const (fun repo token -> Pipeline.Source.github ~repo ~token)
      $ repo
      $ github_token_path)
end

module Config = struct
  let docker_cpuset_cpus =
    let doc =
      "CPU/core that should run the benchmarks. A comma-separated list or \
       hyphen-separated range of CPUs a container can use, if you have more \
       than one CPU"
    in
    Arg.(value & opt (some string) None & info [ "docker-cpu" ] ~doc)

  let docker_numa_node =
    let doc =
      "NUMA node to use for memory and tmpfs storage (should match CPU core if \
       enabled, see `lscpu`)"
    in
    Arg.(value & opt (some int) None & info [ "docker-numa-node" ] ~doc)

  let docker_shm_size =
    let doc = "Size of tmpfs volume to be mounted in /dev/shm (in GB)." in
    Arg.(value & opt int 4 & info [ "docker-shm-size" ] ~doc)

  let slack_path =
    let doc =
      "File containing the Slack endpoint URI to use for result notifications."
    in
    Arg.(value & opt (some path) None & info [ "s"; "slack" ] ~doc)

  let db_uri =
    Arg.required
    @@ Arg.opt Arg.(some uri) None
    @@ Arg.info ~doc:"Connection info for Postgres DB" ~docv:"PATH"
         [ "conn-info" ]

  let config =
    Term.(
      const
        (fun
          current
          docker_cpuset_cpus
          docker_numa_node
          docker_shm_size
          slack_path
          db_uri
        ->
          Pipeline.Config.make ~current ?docker_cpuset_cpus ?docker_numa_node
            ~docker_shm_size ?slack_path ~db_uri ())
      $ Current.Config.cmdliner
      $ docker_cpuset_cpus
      $ docker_numa_node
      $ docker_shm_size
      $ slack_path
      $ db_uri)
end

let setup_log =
  let init style_renderer level =
    Pipeline.Logging.init ?style_renderer ?level ()
  in
  Term.(const init $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let cmd : (Pipeline.Source.t -> (unit, [ `Msg of string ]) result) Term.t =
  Term.(
    const (fun server config () source -> Pipeline.v ~config ~server ~source ())
    $ Current_web.cmdliner
    $ Config.config
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
           ( cmd $ Cmd.local,
             Term.info ~doc:"Monitor a Git repository on disk." "local" );
           ( cmd $ Cmd.github,
             Term.info ~doc:"Monitor a remote GitHub repository." "github" );
           ( cmd $ Cmd.github_app,
             Term.info
               ~doc:"Monitor all repositories associated with github_app."
               "github_app" );
         ])
