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

let validate l =
  let rec loop l acc =
    match l with
    | [] -> Some acc
    | (str, (_, _)) :: l -> (
        match Yojson.Safe.from_string str with
        | j -> (
            match Cb_schema.S.of_json j with
            | s -> loop l (s :: acc)
            | exception Invalid_argument s ->
                Format.eprintf
                  "Some valid json didn't conform to the schema with error: %S\n\
                   The json: %a\n"
                  s
                  (Yojson.Safe.pretty_print ~std:false)
                  j;
                None)
        | exception Yojson.Json_error s ->
            Format.eprintf
              "\x1b[91mJson parsing failure, please report: \x1b[0m%s" s;
            None)
  in
  match loop l [] with
  | None -> ()
  | Some l ->
      let merged = Cb_schema.S.merge [] l |> List.map Cb_schema.S.to_json in
      Format.printf "Correctly parsed %d benchmark(s):\n" (List.length merged);
      List.iter
        (fun j -> Format.printf "%s@;" (Cb_schema.Json.pp_to_string () j))
        merged

let () =
  let ic = if Array.length Sys.argv >= 2 then open_in Sys.argv.(1) else stdin in
  let contents = read_all ic in
  match Cb_schema.P.json_full contents with
  | [] ->
      Format.eprintf
        "\x1b[91mCouldn't parse anything, verify that you output correct \
         json.\x1b[0m\n"
  | l -> validate (List.rev l)
