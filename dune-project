(lang dune 3.7)

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
  "Shakthi Kannan <shakthi@tarides.com>")
 (allow_empty)
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
  (dockerfile
   (>= 6.3.0))
  duration
  fpath
  logs
  (mtime
   (>= 2.0.0))
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
  (alcotest-lwt
   (and
    (>= 1.0.0)
    :with-test))))

(package
 (name cb-check)
 (synopsis "Json schema checker for current-bench")
 (authors "Ambre Austen Suhamy <ambre@tarides.com>")
 (maintainers "Ambre Austen Suhamy <ambre@tarides.com>")
 (depends
  (ocaml
   (>= 4.13.0))
  yojson))
