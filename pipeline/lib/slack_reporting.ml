module Slack = Current_slack
open Current.Syntax

let read_channel_uri p =
  Util.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

let post ~path output =
  let* output = output in
  let content = Engine.Docker_engine.string_of_output output in
  match path with
  | Some path ->
      let channel = read_channel_uri path in
      Slack.post channel ~key:"current-bench-output" (Current.return content)
  | None -> Current.return ()
