let read_all ic =
  let b = Buffer.create 80 in
  let rec loop () =
    let line = input_line ic in
    Buffer.add_string b (line ^ "\n");
    loop ()
  in
  try loop ()
  with End_of_file ->
    close_in ic;
    Buffer.contents b

let pp = Yojson.Safe.pretty_print ~std:false

let validate l =
  let aux (str, _) =
    match Yojson.Safe.from_string str with
    | j -> (
        match Cb_schema.S.of_json j with
        | s -> Some s
        | exception Invalid_argument s ->
            Format.eprintf
              "Some valid json didn't conform to the schema with error: \
               %s@.The json: %a@."
              s pp j;
            None)
    | exception Yojson.Json_error s ->
        Format.eprintf "\x1b[91mJson parsing failure, please report: \x1b[0m%s"
          s;
        exit 1
  in
  match List.filter_map aux l with
  | [] ->
      Format.printf "No schema-valid results were parsed.@.";
      exit 1
  | validated ->
      Format.printf "Correctly parsed following benchmarks:@.";
      Cb_schema.S.merge [] validated
      |> List.iter (fun { Schema.benchmark_name; _ } ->
             Option.value ~default:"unnamed" benchmark_name
             |> Format.printf "%s@.")

let () =
  let ic = if Array.length Sys.argv >= 2 then open_in Sys.argv.(1) else stdin in
  let contents = read_all ic in
  match Json_parsing.full contents with
  | [] ->
      Format.eprintf
        "\x1b[91mCouldn't parse anything, verify that you output correct \
         json.\x1b[0m@.";
      exit 1
  | l -> validate (List.rev l)
