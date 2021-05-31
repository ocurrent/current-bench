module Github = Current_github
module Docker = Current_docker.Default
module Docker_util = Current_util.Docker_util
module Logging = Logging
module Benchmark = Models.Benchmark
module Config = Config

module Source = struct
  type github = { token : Fpath.t; repo : Github.Repo_id.t }

  type t = Github of github | Local of Fpath.t | Github_app of Github.App.t

  let github ~token ~repo = Github { token; repo }

  let local path = Local path

  let github_app t = Github_app t
end

let monitor ~config (source : Source.t) =
  match source with
  | Github { repo; token } ->
      let api = Github_pipeline.github_api_of_oauth_file token in
      let repo = Current.return (api, repo) in
      Github_pipeline.monitor_repo ~config repo
  | Local repo_path -> Local_pipeline.monitor_repo ~config repo_path
  | Github_app app -> Github_pipeline.monitor_app ~config app

let v ~current_config ~docker_config ?slack_path ~server:mode
    ~(source : Source.t) ~db_uri () =
  let config : Config.t = { slack_path; docker = docker_config; db_uri } in
  let pipeline () = monitor ~config source in
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
