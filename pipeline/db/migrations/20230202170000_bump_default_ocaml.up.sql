ALTER TABLE benchmarks ALTER COLUMN docker_image SET DEFAULT 'ocaml/opam:debian-ocaml-5.0';
ALTER TABLE benchmark_metadata ALTER COLUMN docker_image SET DEFAULT 'ocaml/opam:debian-ocaml-5.0';
