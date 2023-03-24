let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "pipeline"
       [ ("api", Api_test.tests); ("json parsing", Json_parsing_test.tests) ]
