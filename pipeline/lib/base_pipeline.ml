open Current.Syntax

let pool = Current.Pool.create ~label:"docker" 1

let conninfo () = assert false

let monitor_commit ~(config : Config.t) commit_context =
  let* commit_context = commit_context in
  let output =
    Postgresql_util.with_connection ~conninfo:(conninfo ()) (fun db ->
        let commit = Commit_context.fetch commit_context in
        let* state = Engine.Docker_engine.build ~pool commit_context commit in
        let* output =
          Engine.Docker_engine.run ~config state commit_context db
        in
        let* () =
          Engine.Docker_engine.complete commit_context state output db
        in
        Current.return output)
  in
  let* () = Slack_reporting.post ~path:config.slack_path output in
  let* () = Github_reporting.post commit_context output in
  Current.return ()
