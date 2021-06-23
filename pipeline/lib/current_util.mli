val get_job_id : 'a Current.t -> string option Current.t

module Docker : sig
  val pread_log :
    ?info:string ->
    ?label:string ->
    ?pool:unit Current.Pool.t ->
    ?run_args:string list ->
    Current_docker.Default.Image.t Current.t ->
    args:string list ->
    string Current.t
  (** Similar to {!val:Current_docker.Default.pred} but includes the output in
      the job's logs and allows passing a custom [info] string. *)
end
