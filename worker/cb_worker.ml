open Cluster_worker
open Lwt.Infix

module Docker_config = struct
  type t = {
    mutable cpus : string list;
    numa_node : int option;
    shm_size : int;
  }

  let v ?(cpus = []) ?numa_node ~shm_size () = { cpus; numa_node; shm_size }

  let cpus_count t = List.length t.cpus

  let acquire_cpu t =
    match t.cpus with
    | [] -> Lwt.fail (Failure "No CPU available")
    | first :: rest ->
        t.cpus <- rest;
        Lwt.return first

  let release_cpu t cpu =
    t.cpus <- cpu :: t.cpus;
    Lwt.return_unit

  let with_cpu t fn =
    acquire_cpu t >>= fun cpu ->
    Lwt.finalize (fun () -> fn cpu) (fun () -> release_cpu t cpu)

  let cpuset_mems t =
    match t.numa_node with
    | Some i -> [ "--cpuset-mems"; string_of_int i ]
    | None -> []

  let tmpfs t =
    match t.numa_node with
    | Some i ->
        [
          "--tmpfs";
          Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg,mpol=bind:%d" t.shm_size i;
        ]
    | None ->
        [ "--tmpfs"; Fmt.str "/dev/shm:rw,noexec,nosuid,size=%dg" t.shm_size ]

  let run_args ~cpu t =
    [
      "--security-opt";
      "seccomp=./aslr_seccomp.json";
      "--mount";
      "type=volume,src=current-bench-data,dst=/home/opam/bench-dir/current-bench-data";
      "--cpuset-cpus";
      cpu;
    ]
    @ tmpfs t
    @ cpuset_mems t
end

let ( >>!= ) = Lwt_result.bind

let ( / ) = Filename.concat

let read_file path =
  let ch = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in ch)
    (fun () ->
      let len = in_channel_length ch in
      really_input_string ch len)

let write_to_file ~path data =
  Lwt_io.(with_file ~mode:output) ~flags:Unix.[ O_TRUNC; O_CREAT; O_RDWR ] path
  @@ fun ch -> Lwt_io.write_from_string_exactly ch data 0 (String.length data)

let try_unlink file =
  if Sys.file_exists file then Lwt_unix.unlink file else Lwt.return_unit

let error_msg fmt = fmt |> Fmt.kstr @@ fun x -> Error (`Msg x)

(* Check [path] points below [src]. Don't follow symlinks. *)
let check_contains ~path src =
  match Fpath.of_string path with
  | Error (`Msg m) -> Error (`Msg m)
  | Ok path ->
      let path = Fpath.normalize path in
      if Fpath.is_abs path
      then error_msg "%a is an absolute path!" Fpath.pp path
      else
        let rec aux ~src = function
          | [] -> error_msg "Empty path!"
          | x :: _ when Fpath.is_rel_seg x ->
              error_msg "Relative segment in %a" Fpath.pp path
          | "" :: _ -> error_msg "Empty segment in %a!" Fpath.pp path
          | x :: xs -> (
              let src = src / x in
              match Unix.lstat src with
              | Unix.{ st_kind = S_DIR; _ } -> aux ~src xs
              | Unix.{ st_kind = S_REG; _ } when xs = [] -> Ok src
              | _ -> error_msg "%S is not a directory (in %a)" x Fpath.pp path
              | exception Unix.Unix_error (Unix.ENOENT, _, _) ->
                  error_msg "%S does not exist (in %a)" x Fpath.pp path)
        in
        aux ~src (Fpath.segs path)

let run_command =
  [
    "/usr/bin/setarch";
    "x86_64";
    "--addr-no-randomize";
    "sh";
    "-c";
    "opam exec -- make bench";
  ]

let docker_run ~switch ~log ~docker_config ~cpu img_hash =
  let run_args = Docker_config.run_args ~cpu docker_config in
  let command =
    ("docker" :: "run" :: run_args) @ [ "--rm"; "-i"; img_hash ] @ run_command
  in
  Process.check_call ~label:"docker-run" ~switch ~log command >>!= fun () ->
  Lwt.return (Ok ())

let docker_run ~switch ~log ~docker_config img_hash =
  Docker_config.with_cpu docker_config @@ fun cpu ->
  docker_run ~switch ~log ~docker_config ~cpu img_hash

let dockerpath ~src = function
  | `Contents contents ->
      let path = src / "Dockerfile" in
      write_to_file ~path contents >>= fun () -> Lwt_result.return path
  | `Path "-" -> Lwt_result.fail (`Msg "Path cannot be '-'!")
  | `Path path -> (
      match check_contains ~path src with
      | Ok path -> Lwt_result.return path
      | Error e -> Lwt_result.fail e)

let docker_build ~switch ~log ~src ~options ~dockerpath ~iid_file =
  let { Cluster_api.Docker.Spec.build_args; squash; _ } = options in
  let args =
    List.concat_map (fun x -> [ "--build-arg"; x ]) build_args
    @ (if squash then [ "--squash" ] else [])
    @ [ "--pull"; "--iidfile"; iid_file; "-f"; dockerpath; src ]
  in
  Process.check_call ~label:"docker-build" ~switch ~log
    ("docker" :: "build" :: args)

let build_and_run ~switch ~log ~src ~docker_config = function
  | `Docker (dockerfile, options) ->
      let iid_file = Filename.temp_file "build-worker-" ".iid" in
      Lwt.finalize
        (fun () ->
          dockerpath ~src dockerfile >>!= fun dockerpath ->
          docker_build ~switch ~log ~options ~src ~dockerpath ~iid_file
          >>!= fun () ->
          let img_hash = String.trim (read_file iid_file) in
          docker_run ~switch ~log ~docker_config img_hash >>!= fun () ->
          Lwt_result.return img_hash)
        (fun () -> try_unlink iid_file)
  | _ -> Lwt_result.fail (`Msg "Unsupported!")

let update () = Lwt.return (fun () -> Lwt.return ())

let or_die = function Ok x -> x | Error (`Msg msg) -> failwith msg

let run ~state_dir ~docker_config ~name ~registration_path =
  let vat = Capnp_rpc_unix.client_only_vat () in
  let sr = Capnp_rpc_unix.Cap_file.load vat registration_path |> or_die in
  let build ~switch ~log ~src ~secrets:_ request =
    build_and_run ~switch ~log ~docker_config ~src request
  in
  let capacity = Docker_config.cpus_count docker_config in
  let worker =
    Cluster_worker.run ~build ~update ~name ~capacity ~state_dir sr
  in
  Lwt_main.run worker

open Cmdliner

module Docker = struct
  let cpus =
    let doc =
      "CPUs/cores that should run the benchmarks, as a comma-separated list if \
       you have more than one CPU"
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

  let v =
    Term.(
      const (fun cpus numa_node shm_size ->
          Docker_config.v ?cpus ?numa_node ~shm_size ())
      $ cpus
      $ numa_node
      $ shm_size)
end

let registration_path =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"Connection pool for OCluster" ~docv:"ocluster-pool"
       [ "ocluster-pool" ]

let worker_name =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"Worker name" ~docv:"name" [ "name" ]

let state_dir =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"Directory for worker internal state" ~docv:"state_dir"
       [ "state-dir" ]

let cmd =
  Term.(
    const (fun docker_config name registration_path state_dir ->
        run ~state_dir ~docker_config ~name ~registration_path)
    $ Docker.v
    $ worker_name
    $ registration_path
    $ state_dir)

let () = Term.exit (Term.eval (cmd, Term.info "cb worker"))
