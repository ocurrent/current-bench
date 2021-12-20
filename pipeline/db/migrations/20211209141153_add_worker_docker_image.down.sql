ALTER TABLE benchmarks
DROP CONSTRAINT unique_run,
DROP COLUMN worker,
DROP COLUMN docker_image,
ADD CONSTRAINT benchmark_metadata_repo_id_commit_key UNIQUE (repo_id, commit);
