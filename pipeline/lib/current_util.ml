open Current.Syntax

let get_job_id x =
  let+ md = Current.Analysis.metadata x in
  match md with Some { Current.Metadata.job_id; _ } -> job_id | None -> None

module Docker_util = struct
  module Docker = Current_docker.Default
  module Image = Current_docker.Raw.Image
  module Cmd = Current_docker.Raw.Cmd

  module Pread_log_builder = struct
    open Lwt.Infix

    type t = { pool : unit Current.Pool.t option }

    let id = "docker-pread"

    module Key = struct
      type t = {
        image : Image.t;
        args : string list;
        docker_context : string option;
        run_args : string list;
        branch : string option;
        pull_number : int option;
        commit : string;
      }

      let cmd
          {
            image;
            args;
            docker_context;
            run_args;
            branch = _;
            pull_number = _;
            commit = _;
          } =
        Cmd.docker ~docker_context
        @@ [ "run" ]
        @ run_args
        @ [ "--rm"; "-i"; Image.hash image ]
        @ args

      let pp f t = Cmd.pp f (cmd t)

      let digest
          { image; args; docker_context; run_args; branch; pull_number; commit }
          =
        Yojson.Safe.to_string
        @@ `Assoc
             [
               ("image", `String (Image.hash image));
               ( "branch",
                 branch
                 |> Option.map (fun x -> `String x)
                 |> Option.value ~default:`Null );
               ( "pull_number",
                 pull_number
                 |> Option.map (fun x -> `Int x)
                 |> Option.value ~default:`Null );
               ("commit", `String commit);
               ("args", `List (List.map (fun arg -> `String arg) args));
               ( "docker_context",
                 docker_context
                 |> Option.map (fun x -> `String x)
                 |> Option.value ~default:`Null );
               ("run_args", `List (List.map (fun arg -> `String arg) run_args));
             ]
    end

    module Value = Current.String

    let build { pool } job key =
      let branch = Key.(key.branch) |> Option.value ~default:"None" in
      let pull_number =
        match Key.(key.pull_number) with
        | Some pull_number -> string_of_int pull_number
        | None -> "None"
      in
      Current.Job.log job "Branch: %s - PR: %s - Commit: %s" branch pull_number
        Key.(key.commit);
      Current.Job.start job ?pool ~level:Current.Level.Average >>= fun () ->
      Current.Process.check_output ~cancellable:true ~job (Key.cmd key)
      >>= fun output_result ->
      match output_result with
      | Ok output ->
          Current.Job.log job "Output:\n%s" output;
          Lwt.return output_result
      | Error (`Msg msg) ->
          Current.Job.log job "Error: %s" msg;
          Lwt.return output_result

    let pp = Key.pp

    let auto_cancel = true
  end

  module Pread_log = Current_cache.Make (Pread_log_builder)

  module Raw = struct
    let pread_log ~docker_context ?pool ?(run_args = []) ?branch ?pull_number
        image ~commit ~args =
      let image =
        Current_docker.Default.Image.hash image
        |> Current_docker.Raw.Image.of_hash
      in
      Pread_log.get { Pread_log_builder.pool }
        {
          Pread_log_builder.Key.image;
          args;
          docker_context;
          run_args;
          branch;
          pull_number;
          commit;
        }
  end

  let pp_sp_label = Fmt.(option (sp ++ string))

  let pread_log ?label ?pool ?run_args image ?branch ?pull_number ~commit ~args
      =
    Current.component "pread_log%a" pp_sp_label label
    |> let> image = image in
       Raw.pread_log ~docker_context:Docker.docker_context ?pool ?run_args image
         ?branch ?pull_number ~commit ~args
end
