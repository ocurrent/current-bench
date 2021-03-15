open Current.Syntax

let get_job_id x =
  let+ md = Current.Analysis.metadata x in
  match md with Some { Current.Metadata.job_id; _ } -> job_id | None -> None
