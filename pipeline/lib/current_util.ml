open Current.Syntax

let get_job_id x =
  let+ md = Current.Analysis.metadata x in
  match md with Some { Current.Metadata.job_id; _ } -> job_id | None -> None

module Docker = struct
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
        info : string option; (* arbitrary user info to be logged *)
      }

      let cmd { image; args; docker_context; run_args; _ } =
        Cmd.docker ~docker_context
        @@ [ "run" ]
        @ run_args
        @ [ "--rm"; "-i"; Image.hash image ]
        @ args

      let pp f t = Cmd.pp f (cmd t)

      let digest { image; args; docker_context; run_args; _ } =
        Yojson.Safe.to_string
        @@ `Assoc
             [
               ("image", `String (Image.hash image));
               ("args", [%derive.to_yojson: string list] args);
               ( "docker_context",
                 [%derive.to_yojson: string option] docker_context );
               ("run_args", [%derive.to_yojson: string list] run_args);
             ]
    end

    module Value = Current.String

    let build { pool } job key =
      Option.iter (Current.Job.log job "Info: %s") Key.(key.info);
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
    let pread_log ~docker_context ?info ?pool ?(run_args = []) image ~args =
      let image =
        Current_docker.Default.Image.hash image
        |> Current_docker.Raw.Image.of_hash
      in
      Pread_log.get { Pread_log_builder.pool }
        { Pread_log_builder.Key.image; args; docker_context; run_args; info }
  end

  let pp_sp_label = Fmt.(option (sp ++ string))

  let pread_log ?info ?label ?pool ?run_args image ~args =
    Current.component "pread%a" pp_sp_label label
    |> let> image = image in
       Raw.pread_log ~docker_context:Docker.docker_context ?info ?pool ?run_args
         image ~args
end
