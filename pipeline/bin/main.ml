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
    Term.(
      const (fun repo token webhook_secret ->
          match (repo, token) with
          | Some repo, Some token ->
              let token = Fpath.v token in
              [ Pipeline.Source.github ~repo ~token ~webhook_secret ]
          | _ -> [])
      $ repo
      $ github_token_path
      $ github_webhook_secret)

  let local_dir =
    let doc =
      "Path to directory containing multiple Git repositories on disk"
    in
    let path =
      Arg.(value & opt (some path) None & info [ "local-repo-dir" ] ~doc)
    in
    Term.(
      const (function
        | None -> []
        | Some path ->
            let path_str = Fpath.to_string path in
            path_str
            |> Sys.readdir
            |> Array.map (fun p -> String.concat Fpath.dir_sep [ path_str; p ])
            |> Array.to_list
            |> List.filter Sys.is_directory
            |> List.map Fpath.v
            |> List.map Pipeline.Source.local)
      $ path)

  let current_github_app =
    Term.(const Pipeline.Source.github_app $ Current_github.App.cmdliner)

  let github_app app_id allowlist key secret =
    match List.filter (( <> ) "") [ app_id; allowlist; key; secret ] with
    | [ app_id; allowlist; key; secret ] -> (
        let argv =
          [|
            "github_app";
            "--github-app-id=" ^ app_id;
            "--github-account-allowlist=" ^ allowlist;
            "--github-private-key-file=" ^ key;
            "--github-webhook-secret-file=" ^ secret;
          |]
        in
        let info =
          Cmd.info
            ~doc:"Monitor all repositories associated with the Github app."
            "github_app"
        in
        match Cmd.eval_value ~argv (Cmd.v info current_github_app) with
        | Ok (`Ok y) -> [ y ]
        | _ -> [])
    | _ -> []

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
      const (fun local_dir github github_app -> local_dir @ github @ github_app)
      $ local_dir
      $ github
      $ github_app)
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

let frontend_url =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"URL of the frontend" ~docv:"URL" [ "frontend-url" ]

let pipeline_url =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"URL of the ocurrent pipeline" ~docv:"URL" [ "pipeline-url" ]

let config_file =
  let arg =
    Arg.required
    @@ Arg.opt Arg.(some path) None
    @@ Arg.info ~doc:"Config file for repositories" ~docv:"PATH"
         [ "repositories" ]
  in
  Term.(
    const (fun frontend_url pipeline_url config_file ->
        Pipeline.Config.of_file ~frontend_url ~pipeline_url config_file)
    $ frontend_url
    $ pipeline_url
    $ arg)

let cmd : (unit, string) result Term.t =
  Term.(
    const (fun config server conninfo () sources ->
        match Pipeline.v ~config ~server ~sources conninfo () with
        | Ok _ -> Result.Ok ()
        | Error (`Msg e) -> Result.Error e)
    $ config_file
    $ Current_web.cmdliner
    $ conninfo
    $ setup_log
    $ Source.sources)

let () =
  Stdlib.exit
  @@ Cmd.eval_result
       (Cmd.v (Cmd.info ~doc:"Monitor all configured repositories." "all") cmd)
