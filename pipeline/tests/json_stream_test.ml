let parsed_location =
  let module M = struct
    type t = string * (int * int)

    let pp ppf s =
      match s with
      | s, (beg, end_) ->
          Format.pp_print_string ppf
            (Printf.sprintf "(%s, (%d, %d))" s beg end_)

    let equal x y = x = y
  end in
  (module M : Alcotest.TESTABLE with type t = M.t)

let parse_one =
  Alcotest_lwt.test_case_sync "parse one" `Quick @@ fun () ->
  let str =
    String.concat "\n"
      [
        "debug line\r\r";
        {|{"json": true}|};
        "more stuff";
        "(Reading database ...\r(Reading database ... 5%";
        "more stuff";
        {|{"ok": ["yes"]}|};
        "...";
      ]
  in
  let state = Json_stream.make_json_parser () in
  let parsed, _state = Json_stream.json_steps ([], state) str in
  let expect =
    [ ({|{"ok": ["yes"]}|}, (8, 8)); ({|{"json": true}|}, (3, 3)) ]
  in
  Alcotest.(check (list parsed_location)) "jsons" expect parsed

let parse_two =
  Alcotest_lwt.test_case_sync "parse two" `Quick @@ fun () ->
  let str =
    String.concat "\n" [ {|{"json": true}|}; "ignore"; "this"; {|{"ok|} ]
  in
  let state = Json_stream.make_json_parser () in
  let parsed, state = Json_stream.json_steps ([], state) str in
  let expect = [ ({|{"json": true}|}, (1, 1)) ] in
  Alcotest.(check (list parsed_location)) "jsons" expect parsed;
  let str = String.concat "\n" [ {|": {"more":|}; {| "is coming"}}|}; "{" ] in
  let parsed, _state = Json_stream.json_steps ([], state) str in
  let expect = [ ({|{"ok": {"more": "is coming"}}|}, (4, 5)) ] in
  Alcotest.(check (list parsed_location)) "jsons" expect parsed;
  ()

  let parse_wrong =
  Alcotest_lwt.test_case_sync "parse wrong" `Quick @@ fun () ->
    let str = "{{{ this isn't json }}}" in
    let state = Json_stream.make_json_parser () in
    let parsed, _state2 = Json_stream.json_steps ([], state) str in
    let expect = [] in
    Alcotest.(check (list parsed_location)) "jsons" expect parsed;
  ()
    

let tests = [ parse_one; parse_two ; parse_wrong]
