ALTER TABLE benchmark_metadata
DROP CONSTRAINT unique_run,
ADD CONSTRAINT unique_run UNIQUE(repo_id, commit, target_version, worker, docker_image);
