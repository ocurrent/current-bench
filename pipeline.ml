(* This pipeline monitors a GitHub repository and uses Docker to build the
   latest version on the default branch. *)

open Current.Syntax
module Git = Current_git
module Github = Current_github
module Docker = Current_docker.Default
module Slack = Current_slack

let () = Logging.init ()

let generate_diff =
  let json_1 = 

let read_channel_uri path =
  let path = match path with None -> raise ("slack_path is missing") | Some path -> path in
  let ch = open_in path in
  let uri = input_line ch in
  close_in ch;
  Current_slack.channel (Uri.of_string (String.trim uri))

(* Generate a Dockerfile for building all the opam packages in the build context. *)
let dockerfile ~base =
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run
       "sudo apt-get install -qq -yy libffi-dev liblmdb-dev m4 pkg-config \
        gnuplot-x11"
  @@ copy ~src:[ "--chown=opam:opam ." ] ~dst:"index" ()
  @@ workdir "index"
  @@ run "opam install -y --deps-only -t ."
  @@ add ~src:[ "--chown=opam ." ] ~dst:"." ()
  @@ run "opam config exec -- make -C ."
  @@ run "eval $(opam env)"

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let read_json filename =
  let ch = open_in filename in
  let s = really_input_string ch (in_channel_length ch) in
  close_in ch;
  s

let pipeline ~github ~repo ~output_file ~slack_path () =
  let output_file =
    match output_file with
    | None -> "/data/gargi/index/output.json"
    | Some file -> file
  in
  let head = Github.Api.head_commit github repo in
  let src = Git.fetch (Current.map Github.Api.Commit.id head) in
  let dockerfile =
    let+ base = Docker.pull ~schedule:weekly "ocaml/opam2" in
    dockerfile ~base
  in
  let image = Docker.build ~pull:false ~dockerfile (`Git src) in
  let s =
    let+ () =
      Docker.run
        ~run_args:[ "-v"; "/data/gargi/index:/data/gargi/index" ]
        image
        ~args:
          [
            "dune";
            "exec";
            "--";
            "bench/db_bench.exe";
            "-b";
            "index";
            "-j";
            output_file;
          ]
    in
    read_json output_file
  in
  let channel = read_channel_uri slack_path in
  Slack.post channel ~key:"output" s

let webhooks = [ ("github", Github.input_webhook) ]

let main config mode github repo output_file slack_path =
  let engine =
    Current.Engine.create ~config
      (pipeline ~github ~repo ~output_file ~slack_path)
  in
  Logging.run
    (Lwt.choose
       [ Current.Engine.thread engine; Current_web.run ~mode ~webhooks engine ])

(* Command-line parsing *)

open Cmdliner

let output_file =
  let doc = "output file where benchmark result should be stored" in
  Arg.(value & opt (some non_dir_file) None & info [ "o"; "output" ] ~doc)

let slack_path =
  let doc = "" in
  Arg.(value & opt (some non_dir_file) None & info [ "s"; "slack" ] ~doc)

let repo =
  Arg.required
  @@ Arg.pos 0 (Arg.some Github.Repo_id.cmdliner) None
  @@ Arg.info ~doc:"The GitHub repository (owner/name) to monitor." ~docv:"REPO"
       []

let cmd =
  let doc = "Monitor a GitHub repository." in
  ( Term.(
      const main $ Current.Config.cmdliner $ Current_web.cmdliner
      $ Current_github.Api.cmdliner $ repo $ output_file $ slack_path),
    Term.info "github" ~doc )

let () = Term.(exit @@ eval cmd)
