open Cmdliner

let path = Arg.conv ~docv:"PATH" Fpath.(of_string, pp)

module Source = struct
  let github =
    let repo =
      Arg.value
      @@ Arg.pos 0 (Arg.some Current_github.Repo_id.cmdliner) None
      @@ Arg.info ~doc:"The GitHub repository (owner/name) to monitor."
           ~docv:"REPO" []
    in
    let github_token_path =
      Arg.value
      @@ Arg.opt Arg.(some file) None
      @@ Arg.info ~doc:"A file containing the GitHub OAuth token." ~docv:"PATH"
           [ "github-token-file" ]
    in
    let github_webhook_secret =
      Arg.required
      @@ Arg.opt Arg.(some string) (Some "")
      @@ Arg.info ~doc:"The GitHub secret to secure webhooks."
           [ "github-webhook-secret" ]
    in
    let slack_path =
      let doc =
        "File containing the Slack endpoint URI to use for result \
         notifications."
      in
      Arg.(value & opt (some file) None & info [ "s"; "slack" ] ~doc)
    in
    Term.(
      const (fun repo token webhook_secret slack_path ->
          match (repo, token) with
          | Some repo, Some token ->
              let token = Fpath.v token in
              let slack_path = Option.map Fpath.v slack_path in
              [
                Pipeline.Source.github ~repo ~token ~webhook_secret ~slack_path;
              ]
          | _ -> [])
      $ repo
      $ github_token_path
      $ github_webhook_secret
      $ slack_path)

  let local =
    let doc = "Path to a Git repository on disk" in
    let path =
      Arg.(value & opt (some path) None & info [ "local-repo" ] ~doc)
    in
    Term.(
      const (function
        | None -> []
        | Some path -> [ Pipeline.Source.local path ])
      $ path)

  let current_github_app =
    ( Term.(const Pipeline.Source.github_app $ Current_github.App.cmdliner),
      Term.info ~doc:"Monitor a Git repository on disk." "github_app" )

  let github_app app_id allowlist key secret =
    match (app_id, allowlist, key, secret) with
    | "", "", "", "" -> []
    | app_id, allowlist, key, secret -> (
        let argv =
          [|
            "github_app";
            "--github-app-id=" ^ app_id;
            "--github-account-allowlist=" ^ allowlist;
            "--github-private-key-file=" ^ key;
            "--github-webhook-secret-file=" ^ secret;
          |]
        in
        match Term.eval ~argv current_github_app with `Ok x -> [ x ] | _ -> [])

  let app_id =
    Arg.(required & opt (some string) (Some "") & info [ "github-app-id" ])

  let allowlist =
    Arg.(
      required
      & opt (some string) (Some "")
      & info [ "github-account-allowlist" ])

  let key =
    Arg.(
      required
      & opt (some string) (Some "")
      & info [ "github-private-key-file" ])

  let secret =
    Arg.(
      required
      & opt (some string) (Some "")
      & info [ "github-webhook-secret-file" ])

  let github_app = Term.(const github_app $ app_id $ allowlist $ key $ secret)

  let sources =
    Term.(
      const (fun local github github_app -> local @ github @ github_app)
      $ local
      $ github
      $ github_app)
end

module Docker = struct
  let cpu =
    let doc =
      "CPU/core that should run the benchmarks. A comma-separated list or \
       hyphen-separated range of CPUs a container can use, if you have more \
       than one CPU"
    in
    Arg.(
      value
      & opt (some (list ~sep:',' string)) None
      & info [ "docker-cpu" ] ~doc)

  let numa_node =
    let doc =
      "NUMA node to use for memory and tmpfs storage (should match CPU core if \
       enabled, see `lscpu`)"
    in
    Arg.(value & opt (some int) None & info [ "docker-numa-node" ] ~doc)

  let shm_size =
    let doc = "Size of tmpfs volume to be mounted in /dev/shm (in GB)." in
    Arg.(value & opt int 4 & info [ "docker-shm-size" ] ~doc)

  let multicore_repositories =
    let doc = "The repositories that should run on multiple cores." in
    Arg.(
      value
      & opt (list ~sep:',' string) []
      & info [ "multicore-repositories" ] ~doc)

  let v =
    Term.(
      const (fun cpu numa_node shm_size multicore_repositories ->
          Pipeline.Docker_config.v ?cpu ?numa_node ~shm_size
            ~multicore_repositories ())
      $ cpu
      $ numa_node
      $ shm_size
      $ multicore_repositories)
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

let cmd : (unit, [ `Msg of string ]) result Term.t =
  Term.(
    const (fun current_config server docker_config conninfo () sources ->
        Pipeline.v ~current_config ~docker_config ~server ~sources conninfo ())
    $ Current.Config.cmdliner
    $ Current_web.cmdliner
    $ Docker.v
    $ conninfo
    $ setup_log
    $ Source.sources)

let () =
  (*
  let default =
    let default_info =
      let doc = "Continuously benchmark a Git repository." in
      Term.info ~doc "pipeline"
    in
    Term.(ret (const (`Help (`Auto, None))), default_info)
  in
  *)
  Term.(
    exit
    @@ eval (cmd, Term.info ~doc:"Monitor all configured repositories." "all"))
