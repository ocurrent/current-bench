let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "pipeline"
       [ ("api", Api_test.tests); ("json_stream", Json_stream_test.tests) ]
