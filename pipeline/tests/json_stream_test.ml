let parse_one =
  Alcotest_lwt.test_case_sync "parse one" `Quick @@ fun () ->
  let str =
    String.concat "\n"
      [
        "debug line";
        {|{"json": true}|};
        "more stuff";
        "more stuff";
        {|{"ok": ["yes"]}|};
        "...";
      ]
  in
  let state = Json_stream.make_json_parser () in
  let parsed, _state = Json_stream.json_steps ([], state) str in
  let expect = [ {|{"ok": ["yes"]}|}; {|{"json": true}|} ] in
  Alcotest.(check (list string)) "jsons" expect parsed

let parse_two =
  Alcotest_lwt.test_case_sync "parse two" `Quick @@ fun () ->
  let str =
    String.concat "\n" [ {|{"json": true}|}; "ignore"; "this"; {|{"ok|} ]
  in
  let state = Json_stream.make_json_parser () in
  let parsed, state = Json_stream.json_steps ([], state) str in
  let expect = [ {|{"json": true}|} ] in
  Alcotest.(check (list string)) "jsons" expect parsed;
  let str = String.concat "\n" [ {|": {"more":|}; {| "is coming"}}|}; "{" ] in
  let parsed, _state = Json_stream.json_steps ([], state) str in
  let expect = [ {|{"ok": {"more": "is coming"}}|} ] in
  Alcotest.(check (list string)) "jsons" expect parsed;
  ()

let tests = [ parse_one; parse_two ]
