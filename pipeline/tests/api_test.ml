let example_conf =
  [
    { Config.repo = "myowner/myrepo"; token = "p455word!" };
    { Config.repo = "other/fst"; token = "token-should-be-unique" };
    { Config.repo = "other/snd"; token = "token-should-be-unique" };
  ]

(* TODO: Cohttp should not be required for testing auth *)
let cohttp_request ~bearer =
  let uri = Uri.of_string "http://localhost/" in
  let headers = Cohttp.Header.of_list [ ("Authorization", bearer) ] in
  Cohttp.Request.make ~headers uri

let cohttp_unauth_request =
  let uri = Uri.of_string "http://localhost/" in
  Cohttp.Request.make uri

let server_not_configured =
  Alcotest_lwt.test_case_sync "server not configured" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Bearer 123" in
  try
    let _ = Api.authenticate_token req [] in
    Alcotest.fail "expected failure"
  with Api.Server_config_error -> ()

let missing_bearer =
  Alcotest_lwt.test_case_sync "missing bearer" `Quick @@ fun () ->
  let req = cohttp_unauth_request in
  try
    let _ = Api.authenticate_token req example_conf in
    Alcotest.fail "expected failure"
  with Api.Missing_token -> ()

let invalid_bearer =
  Alcotest_lwt.test_case_sync "invalid bearer" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Missing Bearer Prefix" in
  try
    let _ = Api.authenticate_token req example_conf in
    Alcotest.fail "expected failure"
  with Api.Invalid_token -> ()

let wrong_token =
  Alcotest_lwt.test_case_sync "wrong token" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Bearer wrong-token" in
  match Api.authenticate_token req example_conf with
  | None -> ()
  | Some repo ->
      Alcotest.fail
        (Printf.sprintf "did not expect repository %S to be found"
           repo.Config.repo)

let find_repository =
  Alcotest_lwt.test_case_sync "find repository" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Bearer p455word!" in
  match Api.authenticate_token req example_conf with
  | None -> Alcotest.fail "expected a repository to be found"
  | Some repo ->
      Alcotest.(check string) "token" repo.Config.token "p455word!";
      Alcotest.(check string) "repo" repo.Config.repo "myowner/myrepo"

let find_other_repository =
  Alcotest_lwt.test_case_sync "find other repository" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Bearer token-should-be-unique" in
  match Api.authenticate_token req example_conf with
  | None -> Alcotest.fail "expected a repository to be found"
  | Some repo -> Alcotest.(check string) "repo" repo.Config.repo "other/fst"

open Lwt.Syntax

let ocurrent_site = Current_web.Site.v ~has_role:(fun _ _ -> false) []

let invalid_json =
  Alcotest_lwt.test_case "invalid json" `Quick @@ fun _ () ->
  let conninfo = Postgresql.Mock.unused_conninfo in
  let req = cohttp_request ~bearer:"Bearer token-should-be-unique" in
  let body = Cohttp_lwt.Body.of_string "this is not json" in
  let handler = Api.capture_metrics conninfo example_conf in
  let* resp, body = handler#post_raw ocurrent_site req body in
  let* body = Cohttp_lwt.Body.to_string body in
  Alcotest.(check string)
    "body" body
    {|{"success":false,"error":"Line 1, bytes 0-16:\nInvalid token 'this is not json'"}|};
  assert (Cohttp.Response.status resp = `Bad_request);
  Lwt.return_unit

let empty_benchmarks =
  Alcotest_lwt.test_case "empty benchmarks" `Quick @@ fun _ () ->
  let expected_sql =
    [
      Postgresql.Expect
        (fun ?expect query ->
          let expected =
            "INSERT INTO benchmark_metadata (run_at, repo_id, commit, \
             commit_message, branch, pull_number, pr_title, worker, \
             docker_image) VALUES (to_timestamp(XXX), 'myowner/myrepo', \
             'abcd12345', NULL, 'main', NULL, NULL, 'remote', 'external') ON \
             CONFLICT(repo_id, commit, worker, docker_image) DO UPDATE SET \
             build_job_id = NULL, run_job_id = NULL, failed = false, cancelled \
             = false, success = false, reason = '' RETURNING id;"
          in
          Alcotest.(check string) "setup metadata" expected query;
          assert (expect = None);
          [| [| "421" |] |]);
      Postgresql.Expect_finish;
      Postgresql.Expect
        (fun ?expect query ->
          let expected =
            "UPDATE benchmark_metadata SET success = true, failed = false, cancelled = false, reason = '' WHERE id = 421"
          in
          Alcotest.(check string) "success" expected query;
          assert (expect = Some [ Postgresql.Command_ok ]);
          [||]);
      Postgresql.Expect_finish;
    ]
  in
  Postgresql.Mock.with_mock expected_sql @@ fun ~conninfo ->
  let req = cohttp_request ~bearer:"Bearer p455word!" in
  let input_json =
    `Assoc
      [
        ("repo_owner", `String "myowner");
        ("repo_name", `String "myrepo");
        ("branch", `String "main");
        ("commit", `String "abcd12345");
        ("run_at", `String "2021-02-03 10:11:12Z");
        ("benchmarks", `List []);
      ]
  in
  let body = Yojson.Safe.to_string input_json in
  let body = Cohttp_lwt.Body.of_string body in
  let handler = Api.capture_metrics conninfo example_conf in
  let* resp, body = handler#post_raw ocurrent_site req body in
  let* body = Cohttp_lwt.Body.to_string body in
  Alcotest.(check string) "body" body {|{"success":true}|};
  assert (Cohttp.Response.status resp = `OK);
  Lwt.return_unit

let tests =
  [
    server_not_configured;
    missing_bearer;
    invalid_bearer;
    wrong_token;
    find_repository;
    find_other_repository;
    invalid_json;
    empty_benchmarks;
  ]
