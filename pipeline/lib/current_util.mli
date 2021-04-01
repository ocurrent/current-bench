val get_job_id : 'a Current.t -> string option Current.t

module Docker_util : sig
  val pread_log :
    ?label:string ->
    ?pool:unit Current.Pool.t ->
    ?run_args:string list ->
    Current_docker.Default.Image.t Current.t ->
    repo_info:string ->
    ?branch:string ->
    ?pull_number:int ->
    commit:string ->
    args:string list ->
    string Current.t
  (** Similar to {!val:Current_docker.Default.pred} but includes the output in
      the job's logs. *)
end
