open Lwt.Infix

type t = string Current.t

let next clock_descr =
  let timeline = Timere.inter [ Timere.after (Timedesc.now ()); clock_descr ] in
  match Timere.resolve timeline with
  | Error msg -> failwith ("Clock.next: " ^ msg)
  | Ok timeline -> (
      match timeline () with
      | Seq.Cons ((t_start, _), _) -> Timedesc.Timestamp.to_float_s t_start
      | _ -> failwith "Clock.next: terminated")

let now () = Timedesc.Timestamp.(to_float_s @@ now ())

let rec sleep_until date =
  let now = now () in
  if now > date
  then Lwt.return_unit
  else Lwt_unix.sleep (date -. now +. 1.) >>= fun () -> sleep_until date

let wait_next clock_descr = sleep_until (next clock_descr)
let to_rfc3339 t = Option.get @@ Timedesc.to_rfc3339 t
let now_rfc3339 () = to_rfc3339 @@ Timedesc.now ()

let beginning_of_time =
  Result.get_ok
  @@ Timedesc.make ~year:2000 ~month:1 ~day:1 ~hour:0 ~minute:0 ~second:0 ()

let monitor clock_descr =
  let now = ref beginning_of_time in
  let read () =
    (* The first [read ()] is far in the past to avoid running the benchmarks
     * when the pipeline is (re)started, but it will then be correct when this
     * cron clock should actually trigger. *)
    Lwt.return (Ok (to_rfc3339 !now))
  in
  let watch refresh =
    let rec wait () =
      wait_next clock_descr >>= fun () ->
      now := Timedesc.now ();
      refresh ();
      wait ()
    in

    let thread = wait () in
    Lwt.return (fun () ->
        Lwt.cancel thread;
        Lwt.return_unit)
  in
  let pp h = Fmt.string h "clock" in
  Current.Monitor.create ~read ~watch ~pp

let make clock_descr =
  let open Current.Syntax in
  Current.component "%s" clock_descr
  |> let> () = Current.return () in
     Current.Monitor.get (monitor (Timere_parse.timere_exn clock_descr))
