ALTER TABLE benchmarks
ADD COLUMN worker varchar(256) NOT NULL DEFAULT 'autumn',
ADD COLUMN docker_image varchar(256) NOT NULL DEFAULT 'ocaml/opam:debian-11-ocaml-4.13';

ALTER TABLE benchmark_metadata
DROP CONSTRAINT benchmark_metadata_repo_id_commit_key,
ADD COLUMN worker varchar(256) NOT NULL DEFAULT 'autumn',
ADD COLUMN docker_image varchar(256) NOT NULL DEFAULT 'ocaml/opam:debian-11-ocaml-4.13',
ADD CONSTRAINT unique_run UNIQUE (repo_id, commit, worker, docker_image);
