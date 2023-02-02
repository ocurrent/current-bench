ALTER TABLE benchmarks ALTER COLUMN docker_image SET DEFAULT 'ocaml/opam:debian-11-ocaml-4.13';
ALTER TABLE benchmark_metadata ALTER COLUMN docker_image SET DEFAULT 'ocaml/opam:debian-11-ocaml-4.13';
