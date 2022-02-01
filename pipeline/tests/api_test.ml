let example_conf =
  [
    { Config.repo = "myowner/repo"; token = "p455word!" };
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
  Alcotest.test_case "server not configured" `Quick @@ fun () ->
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
  Alcotest.test_case "invalid bearer" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Missing Bearer Prefix" in
  try
    let _ = Api.authenticate_token req example_conf in
    Alcotest.fail "expected failure"
  with Api.Invalid_token -> ()

let wrong_token =
  Alcotest.test_case "wrong token" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Bearer wrong-token" in
  match Api.authenticate_token req example_conf with
  | None -> ()
  | Some repo ->
      Alcotest.fail
        (Printf.sprintf "did not expect repository %S to be found"
           repo.Config.repo)

let find_repository =
  Alcotest.test_case "find repository" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Bearer p455word!" in
  match Api.authenticate_token req example_conf with
  | None -> Alcotest.fail "expected a repository to be found"
  | Some repo ->
      Alcotest.(check string) "token" repo.Config.token "p455word!";
      Alcotest.(check string) "token" repo.Config.repo "myowner/repo"

let find_other_repository =
  Alcotest.test_case "find other repository" `Quick @@ fun () ->
  let req = cohttp_request ~bearer:"Bearer token-should-be-unique" in
  match Api.authenticate_token req example_conf with
  | None -> Alcotest.fail "expected a repository to be found"
  | Some repo -> Alcotest.(check string) "token" repo.Config.repo "other/fst"

let tests =
  [
    server_not_configured;
    missing_bearer;
    invalid_bearer;
    wrong_token;
    find_repository;
    find_other_repository;
  ]
