module Docker = Current_docker.Default
module Images = Map.Make (String)

let default_worker = "autumn"

let default_docker = "ocaml/opam:debian-11-ocaml-4.13"

type repo = {
  name : string;
  worker : string; [@default default_worker]
  image : string; [@default default_docker]
}
[@@deriving yojson]

type repo_list = repo list [@@deriving yojson]

type t = { repos : repo_list; images : Docker.Image.t Current.t Images.t }

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

let make repos = { repos; images = make_images repos }

let of_file filename : t =
  let filename = Fpath.to_string filename in
  let json = Yojson.Safe.from_file filename in
  match repo_list_of_yojson json with
  | Ok repos -> make repos
  | Error err -> failwith (Printf.sprintf "Config.of_file %S : %s" filename err)

let find t name =
  match List.filter (fun r -> r.name = name) t.repos with
  | [] -> [ { name; worker = default_worker; image = default_docker } ]
  | configs -> configs

let find_image t image_name = Images.find image_name t.images
