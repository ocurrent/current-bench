let unit_conversion =
  Alcotest_lwt.test_case "unit conversion" `Quick @@ fun _ () ->
  let one_ms_in_ns = Units.convert ~from:"ms" ~target:"ns" 1.0 in
  Alcotest.(check (float 0.1)) "One ms in ns" one_ms_in_ns 1_000_000.;
  Lwt.return_unit

let tests = [ unit_conversion ]
