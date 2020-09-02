open Current.Syntax
module Git = Current_git
module Github = Current_github
module Docker = Current_docker.Default
module Slack = Current_slack
module Logging = Logging

let pool = Current.Pool.create ~label:"docker" 1

let read_channel_uri p =
  Utils.read_fpath p |> String.trim |> Uri.of_string |> Current_slack.channel

(* Generate a Dockerfile for building all the opam packages in the build context. *)
let dockerfile ~base =
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run
       "sudo apt-get update && sudo apt-get install -qq -yy libffi-dev \
        liblmdb-dev m4 pkg-config gnuplot-x11"
  @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"index" ()
  @@ workdir "index"
  @@ run "opam install -y --deps-only -t ."
  @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
  @@ run "opam config exec -- dune build @@default bench/bench.exe"
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

let pipeline ?slack_path ~conninfo ~(info : pr_info) ~head ~name ~owner
    ~dockerfile ~tmpfs ~docker_cpuset_cpus ~docker_cpuset_mems =
  let s =
    let run_args =
      [ "--security-opt"; "seccomp=./aslr_seccomp.json" ]
      @ tmpfs
      @ docker_cpuset_cpus
      @ docker_cpuset_mems
    in
    let+ output =
      let src =
        Git.fetch (Current.map Github.Api.Commit.id (Current.return head))
      in
      let image = Docker.build ~pool ~pull:false ~dockerfile (`Git src) in
      Docker.pread ~run_args image
        ~args:
          [
            "/usr/bin/setarch";
            "x86_64";
            "--addr-no-randomize";
            "_build/default/bench/bench.exe";
            "--nb-entries";
            "10000";
            "-d";
            "/dev/shm";
            "--json";
          ]
    in
    let commit = Github.Api.Commit.hash head in
    let content =
      Utils.merge_json name owner commit (Yojson.Basic.from_string output)
    in
    let pr_str = string_pr_info owner name info in
    let () = Utils.populate_postgres conninfo commit content pr_str in
    match slack_path with Some p -> Some (p, content) | None -> None
  in
  s
  |> Current.option_map (fun p ->
         Current.component "post"
         |> let** path, _ = p in
            let channel = read_channel_uri path in
            Slack.post channel ~key:"output" (Current.map snd p))
  |> Current.state
  |> Current.map (github_status_of_state (get_url name owner info))
  |> Github.Api.Commit.set_status (Current.return head) "benchmark"
  |> Current.ignore_value

let process_pipeline ?slack_path ?docker_cpu ?docker_numa_node ~docker_shm_size
    ~conninfo ~github ~(repo : Github.Repo_id.t) () =
  let name = repo.name in
  let owner = repo.owner in
  let dockerfile =
    let+ base = Docker.pull ~schedule:weekly "ocaml/opam2" in
    `Contents (dockerfile ~base)
  in
  let docker_cpuset_cpus =
    match docker_cpu with
    | Some i -> [ "--cpuset-cpus"; string_of_int i ]
    | None -> []
  in
  let docker_cpuset_mems =
    match docker_numa_node with
    | Some i -> [ "--cpuset-mems"; string_of_int i ]
    | None -> []
  in
  let tmpfs =
    match docker_numa_node with
    | Some i ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d"
            docker_shm_size i;
        ]
    | None ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" docker_shm_size;
        ]
  in
  let repo = Current.return (github, repo) in
  let* refs =
    Current.component "Get PRs"
    |> let> api, repo = repo in
       Github.Api.refs api repo
  in
  Github.Api.Ref_map.fold
    (fun key head _ ->
      match key with
      | `Ref "refs/heads/master" ->
          pipeline ?slack_path ~conninfo ~info:(`Branch "master") ~head ~name
            ~owner ~dockerfile ~tmpfs ~docker_cpuset_cpus ~docker_cpuset_mems
      | `PR pr_num ->
          pipeline ?slack_path ~conninfo ~info:(`PR pr_num) ~head ~name ~owner
            ~dockerfile ~tmpfs ~docker_cpuset_cpus ~docker_cpuset_mems
      | `Ref _ -> Current.return ()
      (* Skip all branches other than master, and check PRs *))
    refs (Current.return ())

type token = { token_file : string; token_api_file : Github.Api.t }

let v ~config ~server:mode ~token:github_token ~repo ?slack_path ?docker_cpu
    ?docker_numa_node ~docker_shm_size conninfo () =
  let github = github_token.token_api_file in
  let engine =
    Current.Engine.create ~config
      (process_pipeline ?slack_path ?docker_cpu ?docker_numa_node
         ~docker_shm_size ~conninfo ~github ~repo)
  in
  let routes =
    Routes.((s "webhooks" / s "github" /? nil) @--> Github.webhook)
    :: Current_web.routes engine
  in
  let site =
    Current_web.Site.(v ~has_role:allow_all) ~name:"Benchmarks" routes
  in
  Logging.run
    (Lwt.choose [ Current.Engine.thread engine; Current_web.run ~mode site ])
