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
  Alcotest_lwt.test_case_sync "parse json: invalid" `Quick @@ fun () ->
  let str = "{{{ this isn't json }}}" in
  let parsed = Json_stream.json_full str in
  let expect = [] in
  Alcotest.(check (list parsed_location)) "jsons" expect parsed;
  ()

let parse_wrong_longer =
  Alcotest_lwt.test_case_sync "parse json: longer invalid" `Quick @@ fun () ->
  let str =
    {|{
      s =
        (module struct
          type t = int
    
          let x = 1
        end);
    }|}
  in
  let parsed = Json_stream.json_full str in
  let expect = [] in
  Alcotest.(check (list parsed_location)) "jsons" expect parsed;
  ()

let parse_real_log =
  Alcotest_lwt.test_case_sync "parse json: real log" `Quick @@ fun () ->
  let str =
    {|> Start benchmarks on [fn¹].
    [                                        ] 0%
    [########################################] 100%
    > Merge results.
    > Start linear regression.
    Eqaf.find_uint8: 23845.568626 ns/run.
    String.index: 78.197706 ns/run.
    B¹ = -7.603465, B² = 11355.394897.
    1 trial(s) for Eqaf.find_uint8.
    {"results": [{"name": "eqaf", "metrics": [{"name": "find_uint8", "value": 1}]}]}
    > Start to test Eqaf.divmod (B¹).
    > Start benchmarks on [fn⁰].
    [                                        ] 0%
    [########################################] 100%
    > Start benchmarks on [fn¹].
    [                                        ] 0%
    [########################################] 100%
    > Merge results.
    > Start linear regression.
    > Start to test Int32.unsigned_div,Int32.unsigned_rem (B²).
    > Start benchmarks on [fn⁰].
    [                                        ] 0%
    [########################################] 100%
    > Start benchmarks on [fn¹].
    [                                        ] 0%
    [########################################] 100%
    > Merge results.
    > Start linear regression.
    Eqaf.divmod: 130.514954 ns/run.
    Int32.unsigned_div,Int32.unsigned_rem: 53.477230 ns/run.
    B¹ = 0.014185, B² = -0.136687.
    1 trial(s) for Eqaf.divmod.
    {"results": [{"name": "eqaf", "metrics": [{"name": "divmod", "value": 1}]}]}
    Job succeeded
    2022-05-03 10:02.42: Job succeeded|}
  in
  let parsed = Json_stream.json_full str in
  let expect =
    [
      ( {|{"results": [{"name": "eqaf", "metrics": [{"name": "divmod", "value": 1}]}]}|},
        (33, 33) );
      ( {|{"results": [{"name": "eqaf", "metrics": [{"name": "find_uint8", "value": 1}]}]}|},
        (10, 10) );
    ]
  in
  Alcotest.(check (list parsed_location)) "jsons" expect parsed;
  ()

let parse_non_last_num =
  Alcotest_lwt.test_case_sync "parse json: non-last num" `Quick @@ fun () ->
  let str = {|
  {
    "pi": 3.14,
	  "phi": 1.618
  }|} in
  let parsed = Json_stream.json_full str in
  let expect = [ ({|{    "pi": 3.14,	  "phi": 1.618  }|}, (2, 5)) ] in
  Alcotest.(check (list parsed_location)) "jsons" expect parsed;
  ()

let parse_wrong_then_right =
  Alcotest_lwt.test_case_sync "parse json: valid in invalid" `Quick @@ fun () ->
  let str =
    {|{"Hey now",
    "you're an all star", {"get your game on": "go play"}
    }|}
  in
  let parsed = Json_stream.json_full str in
  let expect = [ ({|{"get your game on": "go play"}|}, (2, 2)) ] in
  Alcotest.(check (list parsed_location)) "jsons" expect parsed;
  ()

let tests =
  [
    parse_one;
    parse_two;
    parse_wrong;
    parse_wrong_longer;
    parse_real_log;
    parse_non_last_num;
    parse_wrong_then_right;
  ]
