(lang dune 2.9)

(name current-bench)

(generate_opam_files true)

(source
 (github ocurrent/current-bench))

(package
 (name current-bench)
 (synopsis "Run continuous benchmarks for repositories")
 (authors "Rizo I. <rizo@tarides.com>" "Gargi Sharma <gargi@tarides.com>")
 (maintainers
  "Ambre Austen Suhamy <ambre@tarides.com>"
  "Puneeth Chaganti <puneeth@tarides.com>"
  "Shakthi Kannan")
 (depends
  (ocaml
   (>= 4.13.0))
  dune
  bechamel
  bos
  capnp-rpc-unix
  (cmdliner
   (>= 1.1.0))
  cohttp-lwt-unix
  (current
   (>= 0.6.4))
  current_ansi
  (current_docker
   (>= 0.6.4))
  (current_git
   (>= 0.6.4))
  (current_github
   (>= 0.6.4))
  (current_incr
   (>= 0.5))
  (current_ocluster
   (>= 0.2.1))
  (current_rpc
   (>= 0.6.4))
  (current_slack
   (>= 0.6.4))
  (current_web
   (>= 0.6.4))
  dockerfile
  duration
  fpath
  logs
  (obuilder
   (>= 0.5.1))
  (obuilder-spec
   (>= 0.5.1))
  (ocluster-api
   (>= 0.2.1))
  (ocluster-worker
   (>= 0.2.1))
  omigrate
  postgresql
  (prometheus-app
   (>= 1.2))
  ptime
  rresult
  (timere
   (>= 0.5.0))
  timere-parse
  yojson
  (alcotest :with-test)
  (alcotest-lwt :with-test)))
