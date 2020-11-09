open Current.Syntax
module Git = Current_git
module Github = Current_github
module Docker = Current_docker.Default
module Slack = Current_slack
module Logging = Logging

let ( >>| ) x f = Current.map f x

module Source = struct
  type github = {
    token : Fpath.t;
    slack_path : Fpath.t option;
    repo : Github.Repo_id.t;
  }

  type t = Github of github | Local of Fpath.t | Github_app of Github.App.t

  let github ~token ~slack_path ~repo = Github { token; slack_path; repo }

  let local path = Local path

  let github_app t = Github_app t
end

module Docker_config = struct
  type t = { cpu : int option; numa_node : int option; shm_size : int }

  let v ?cpu ?numa_node ~shm_size = { cpu; numa_node; shm_size }
end

let pool = Current.Pool.create ~label:"docker" 1

let read_channel_uri p =
  Utils.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

(* Generate a Dockerfile for building all the opam packages in the build context. *)
let dockerfile ~base =
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run
       "sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
        liblmdb-dev m4 pkg-config gnuplot-x11 libgmp-dev libssl-dev"
  @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"bench-dir" ()
  @@ workdir "bench-dir"
  @@ run "opam install -y --deps-only -t ."
  @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
  @@ run "eval $(opam env)"

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 1) ()

type pr_info = [ `PR of int | `Branch of string ]

let string_pr_info owner name info =
  let str = Printf.sprintf "%s/%s/" owner name in
  match info with
  | `PR num -> str ^ string_of_int num
  | `Branch branch -> str ^ branch

let get_url name owner info =
  let autumn_url = "http://autumn.ocamllabs.io:3030/pr/" in
  Uri.of_string (autumn_url ^ string_pr_info owner name info)

let github_status_of_state url = function
  | Ok _ -> Github.Api.Status.v ~url `Success ~description:"Passed"
  | Error (`Active _) -> Github.Api.Status.v ~url `Pending
  | Error (`Msg m) -> Github.Api.Status.v ~url `Failure ~description:m

let pipeline ~slack_path ~conninfo ~(info : pr_info) ~dockerfile ~tmpfs
    ~docker_cpuset_cpus ~docker_cpuset_mems ~head ~name ~owner =
  let src =
    match head with
    | `Github api_commit ->
        Git.fetch (Current.map Github.Api.Commit.id (Current.return api_commit))
    | `Local commit -> commit
  in
  let image = Docker.build ~pool ~pull:false ~dockerfile (`Git src) in
  let s =
    let run_args =
      [ "--security-opt"; "seccomp=./aslr_seccomp.json" ]
      @ tmpfs
      @ docker_cpuset_cpus
      @ docker_cpuset_mems
    in
    let+ output =
      Docker.pread ~run_args image
        ~args:
          [
            "/usr/bin/setarch"; "x86_64"; "--addr-no-randomize"; "make"; "bench";
          ]
    and+ commit =
      match head with
      | `Github api_commit -> Current.return (Github.Api.Commit.hash api_commit)
      | `Local commit -> commit >>| Git.Commit.hash
    in
    let content = Utils.merge_json ~repo:name ~owner ~commit output in
    let () =
      let pr_info = string_pr_info owner name info in
      Utils.populate_postgres ~conninfo ~commit ~json_string:content ~pr_info
    in
    match slack_path with Some p -> Some (p, content) | None -> None
  in
  s
  |> Current.option_map (fun p ->
         Current.component "post"
         |> let** path, _ = p in
            let channel = read_channel_uri path in
            Slack.post channel ~key:"output" (p >>| snd))
  |> Current.state
  |> fun result ->
  match head with
  | `Local _ -> Current.ignore_value result
  | `Github head ->
      result
      >>| github_status_of_state (get_url name owner info)
      |> Github.Api.Commit.set_status (Current.return head) "ocaml-benchmarks"
      |> Current.ignore_value

let process_pipeline ~(docker_config : Docker_config.t) ~conninfo
    ~(source : Source.t) () =
  let dockerfile =
    let+ base = Docker.pull ~schedule:weekly "ocurrent/opam" in
    `Contents (dockerfile ~base)
  in
  let docker_cpuset_cpus =
    match docker_config.cpu with
    | Some i -> [ "--cpuset-cpus"; string_of_int i ]
    | None -> []
  in
  let docker_cpuset_mems =
    match docker_config.numa_node with
    | Some i -> [ "--cpuset-mems"; string_of_int i ]
    | None -> []
  in
  let tmpfs =
    match docker_config.numa_node with
    | Some i ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d"
            docker_config.shm_size i;
        ]
    | None ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" docker_config.shm_size;
        ]
  in
  let pipeline =
    pipeline ~conninfo ~dockerfile ~tmpfs ~docker_cpuset_cpus
      ~docker_cpuset_mems
  in
  match source with
  | Github { repo; slack_path; token } ->
      let pipeline = pipeline ~slack_path ~name:repo.name ~owner:repo.owner in
      let* refs =
        let token =
          token
          |> Utils.read_fpath
          |> String.trim
          |> Current_github.Api.of_oauth
        in
        let repo = Current.return (token, repo) in
        Current.component "Get PRs"
        |> let> api, repo = repo in
           Github.Api.refs api repo
      in
      Github.Api.Ref_map.fold
        (fun key head _ ->
          let head = `Github head in
          match key with
          | `Ref "refs/heads/master" -> pipeline ~head ~info:(`Branch "master")
          | `PR pr_num -> pipeline ~head ~info:(`PR pr_num)
          | `Ref _ -> Current.return ()
          (* Skip all branches other than master, and check PRs *))
        refs (Current.return ())
  | Local path ->
      let head = `Local (Git.Local.head_commit (Git.Local.v path)) in
      pipeline ~info:(`Branch "HEAD") ~head ~name:"local" ~owner:"local"
        ~slack_path:None
  | Github_app app ->
      Github.App.installations app
      |> Current.list_iter (module Github.Installation) @@ fun installation ->
         let repos = Github.Installation.repositories installation in
         repos
         |> Current.list_iter ~collapse_key:"repo" (module Github.Api.Repo)
            @@ fun repo ->
            let* refs =
              Current.component "Get PRS"
              |> let> api, repo = repo in
                 Github.Api.refs api repo
            in
            let* _, repo = repo in
            let pipeline =
              pipeline ~slack_path:None ~name:repo.name ~owner:repo.owner
            in
            Github.Api.Ref_map.fold
              (fun key head _ ->
                let head = `Github head in
                match key with
                | `Ref "refs/heads/master" ->
                    pipeline ~head ~info:(`Branch "master")
                | `PR pr_num -> pipeline ~head ~info:(`PR pr_num)
                | `Ref _ -> Current.return ()
                (* Skip all branches other than master, and check PRs *))
              refs (Current.return ())

let v ~current_config ~docker_config ~server:mode ~(source : Source.t) conninfo
    () =
  let pipeline = process_pipeline ~docker_config ~conninfo ~source in
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
