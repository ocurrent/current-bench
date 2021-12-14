open Current.Syntax

let get_job_id x =
  Current.with_context x (fun () ->
      let+ md = Current.Analysis.metadata x in
      match md with
      | Some { Current.Metadata.job_id; _ } -> job_id
      | None -> None)
