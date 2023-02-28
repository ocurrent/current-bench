(lang dune 2.0)

(name current-bench)

(generate_opam_files true)

(source
 (github ocurrent/current-bench))

(package
 (name current-bench)
 (authors "Rizo I. <rizo@tarides.com>" "Gargi Sharma <gargi@tarides.com>")
 (maintainers
  "Ambre Austen Suhamy <ambre@tarides.com>"
  "Puneeth Chaganti <puneeth@tarides.com>"
  "Shakthi Kannan")
 (depends
  (ocaml
   (>= 4.13.0))
  (dune
   (>= 2.0))
  bechamel
  bos
  capnp-rpc-unix
  (cb-schema :version)
  (cmdliner
   (>= 1.1.0))
  (current
   (>= 0.6.4))
  (current_docker
   (>= 0.6.4))
  (current_git
   (>= 0.6.4))
  (current_github
   (>= 0.6.4))
  (current_rpc
   (>= 0.6.4))
  (current_slack
   (>= 0.6.4))
  (current_web
   (>= 0.6.4))
  (current_incr
   (>= 0.5))
  current_ansi
  (current_ocluster
   (>= 0.2.1))
  dockerfile
  duration
  fpath
  logs
  (ocluster-api
   (>= 0.2.1))
  (ocluster-worker
   (>= 0.2.1))
  (obuilder
   (>= 0.2.1))
  (obuilder-spec
   (>= 0.2.1))
  omigrate
  postgresql
  (prometheus-app
   (>= 1.2))
  rresult
  timere
  timere-parse
  yojson
  (alcotest :with-test)
  (alcotest-lwt :with-test)))

(package
 (name cobench)
 (authors
  "Arthur Wendling <arthur@tarides.com>"
  "Gargi Sharma <gargi@tarides.com>"
  "Puneeth Chaganti <puneeth@tarides.com>")
 (maintainers
  "Arthur Wendling <arthur@tarides.com>"
  "Puneeth Chaganti <puneeth@tarides.com>"
  "Ambre Austen Suhamy <ambre@tarides.com>")
 (depends
  (ocaml
   (>= 4.13.0))
  (dune
   (>= 2.0))
  bechamel
  (cb-schema :version)
  cohttp-lwt-unix
  ptime
  yojson
  (odoc :with-doc)))

(package
 (name cb-schema)
 (authors "Ambre Austen Suhamy <ambre@tarides.com>")
 (maintainers "Ambre Austen Suhamy <ambre@tarides.com>")
 (synopsis "Json schema used in current-bench")
 (depends
  ; DO NOT ADD ANYTHING HERE
  ; See cb_schema.ml for rationale
  ))

(package
 (name cb-check)
 (authors "Ambre Austen Suhamy <ambre@tarides.com>")
 (maintainers "Ambre Austen Suhamy <ambre@tarides.com>")
 (synopsis "Json schema checker for current-bench")
 (depends
  (cb-schema :version)
  yojson))
