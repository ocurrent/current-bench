CREATE INDEX benchmark_metadata_pull_number_idx ON benchmark_metadata (pull_number);
CREATE INDEX benchmark_metadata_repo_id_pull_number_idx ON benchmark_metadata (repo_id, pull_number);
