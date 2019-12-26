(lang dune 2.0)
(name pipeline)

(generate_opam_files true)
(source (github gs0510/index-benchmarks))
(maintainers "Gargi Sharma <gargi@tarides.com>")
(authors "Gargi Sharma <gargi@tarides.com>")

(package
 (name pipeline)
 (synopsis "OCurrent pipeline for index benchmarks")
 (description "This pipeline runs the index benchmarks and publishes them to slack.")
 (depends
  capnp-rpc-unix
  cmdliner
  current
  current_docker
  current_git
  current_github
  current_rpc
  current_slack
  current_web
  duration
  (ocaml (>= 4.08))))
