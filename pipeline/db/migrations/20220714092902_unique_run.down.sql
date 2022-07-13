ALTER TABLE benchmark_metadata
DROP CONSTRAINT unique_run,
ADD CONSTRAINT unique_run UNIQUE(repo_id, commit, worker, docker_image);
