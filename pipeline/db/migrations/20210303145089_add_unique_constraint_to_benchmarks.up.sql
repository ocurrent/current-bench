ALTER TABLE benchmarks
ADD CONSTRAINT prevent_duplicates UNIQUE(commit, test_name, run_job_id);
