module Docker = Current_docker.Default
module Slack = Current_slack
module Images = Map.Make (String)

let default_worker = "autumn"
let default_docker = "ocaml/opam:debian-ocaml-5.0"

type repo = {
  name : string;
  worker : string; [@default default_worker]
  image : string; [@default default_docker]
  dockerfile : string option; [@default None]
  schedule : string option; [@default None]
  build_args : string list; [@default []]
  notify_github : bool; [@default false]
  if_label : string option; [@default None]
  target_version : string option; [@default None]
  target_name : string option; [@default None]
}
[@@deriving yojson]

type repo_list = repo list [@@deriving yojson]
type api_token = { repo : string; token : string } [@@deriving yojson]
type api_token_list = api_token list [@@deriving yojson]

type config = {
  repositories : repo_list;
  api_tokens : api_token_list;
  slack : string option; [@default None]
}
[@@deriving yojson]

module Map_string = Map.Make (String)

type t = {
  repos : repo_list;
  images : Docker.Image.t Current.t Images.t;
  clocks : Clock.t Map_string.t;
  api_tokens : api_token_list;
  slack : Slack.channel option;
  frontend_url : string;
  pipeline_url : string;
}

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let pull img images =
  if Images.mem img images
  then images
  else
    let docker = Docker.pull ~schedule:weekly img in
    Images.add img docker images

let make_images repos =
  List.fold_left
    (fun acc repo ->
      let img = repo.image in
      pull img acc)
    (pull default_docker Images.empty)
    repos

let make_clocks repos =
  List.fold_left
    (fun acc repo ->
      match repo.schedule with
      | None -> acc
      | Some schedule ->
          Map_string.update schedule
            (function None -> Some (Clock.make schedule) | exist -> exist)
            acc)
    Map_string.empty repos

let slack_of_url = function
  | None -> None
  | Some url -> Some (Slack.channel (Uri.of_string url))

let of_file ~frontend_url ~pipeline_url filename : t =
  let filename = Fpath.to_string filename in
  let json = Yojson.Safe.from_file filename in
  match config_of_yojson json with
  | Ok { repositories; api_tokens; slack } ->
      {
        repos = repositories;
        api_tokens;
        images = make_images repositories;
        clocks = make_clocks repositories;
        slack = slack_of_url slack;
        frontend_url;
        pipeline_url;
      }
  | Error err -> failwith (Printf.sprintf "Config.of_file %S : %s" filename err)

let default name =
  {
    name;
    worker = default_worker;
    image = default_docker;
    dockerfile = None;
    schedule = None;
    build_args = [];
    notify_github = false;
    target_version = None;
    target_name = None;
    if_label = None;
  }

let must_benchmark repo conf =
  match (conf.if_label, Repository.pull_number repo) with
  | Some tag, Some _ -> List.mem tag (Repository.labels repo)
  | _ -> true

let find t repo =
  let name = Repository.info repo in
  match List.filter (fun r -> r.name = name) t.repos with
  | [] -> [ default name ]
  | configs -> List.filter (must_benchmark repo) configs

let find_image t image_name = Images.find image_name t.images

let get_clock t repo =
  match repo.schedule with
  | None -> Current.return (Clock.now_rfc3339 ())
  | Some schedule -> Map_string.find schedule t.clocks

let repo_url ~config repo worker docker_image =
  Printf.sprintf "%s/%s?worker=%s&image=%s" config.frontend_url
    (Repository.to_path repo) (Uri.pct_encode worker)
    (Uri.pct_encode docker_image)

let job_url ~config job_id start stop =
  Printf.sprintf "%s/job/%s#L%i-L%i" config.pipeline_url job_id start stop

let key_of_repo ~config repository worker docker_image =
  Printf.sprintf "<%s|*%s* _%s_ %s>"
    (repo_url ~config repository worker docker_image)
    (Repository.to_string repository)
    worker docker_image

open Current.Syntax

let slack_message key msg =
  let+ state = Current.catch ~hidden:true msg in
  let icon, msg =
    match state with
    | Ok msg -> (":heavy_check_mark:", msg)
    | Error (`Msg e) -> (":x: <!here>", "*`" ^ e ^ "`*")
  in
  icon ^ " " ^ key ^ ": " ^ msg

let slack_log ~config ~key msg =
  match config.slack with
  | None -> Current.ignore_value msg
  | Some channel ->
      let+ () = Slack.post channel ~key (slack_message key msg) and+ _ = msg in
      ()
