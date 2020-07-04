open Current.Syntax

module Metrics = struct
  open Prometheus

  let namespace = "ocurrent"

  let subsystem = "logs"

  let inc_messages =
    let help = "Total number of messages logged" in
    let c =
      Counter.v_labels ~label_names:[ "level"; "src" ] ~help ~namespace
        ~subsystem "messages_total"
    in
    fun lvl src ->
      let lvl = Logs.level_to_string (Some lvl) in
      Counter.inc_one @@ Counter.labels c [ lvl; src ]
end

let reporter =
  let report src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    let src = Logs.Src.name src in
    Metrics.inc_messages level src;
    msgf @@ fun ?header ?tags:_ fmt ->
    Fmt.kpf k Fmt.stdout
      ("%a %a @[" ^^ fmt ^^ "@]@.")
      Fmt.(styled `Magenta string)
      (Printf.sprintf "%14s" src)
      Logs_fmt.pp_header (level, header)
  in
  { Logs.report }

let init ?style_renderer ?level () =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter reporter

let run x =
  match Lwt_main.run x with
  | Ok () -> Ok ()
  | Error (`Msg m) as e ->
      Logs.err (fun f -> f "%a" Fmt.lines m);
      e

module SVar = Current.Var (struct
  type t = unit -> unit Current.t

  let equal = ( == )

  let pp f _ = Fmt.string f "pipeline"
end)

let selected = SVar.create ~name:"current-test" (Error (`Msg "no-test"))

let test_pipeline =
  Current.component "choose pipeline"
  |> let** make_pipeline = SVar.get selected in
     make_pipeline ()

let with_dot ~dotfile f () =
  SVar.set selected (Ok f);
  Logs.debug (fun f -> f "Pipeline: @[%a@]" Current.Analysis.pp test_pipeline);
  let path = Fmt.strf "%s.%d.dot" dotfile 1 in
  let ch = open_out path in
  let f = Format.formatter_of_out_channel ch in
  let url _ = None in
  let env = [] in
  Fmt.pf f "%a@!" (Current.Analysis.pp_dot ~env ~url) test_pipeline;
  close_out ch;
  test_pipeline
