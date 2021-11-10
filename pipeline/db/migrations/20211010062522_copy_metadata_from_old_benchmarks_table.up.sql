INSERT INTO benchmark_metadata
(run_at, repo_id, commit, branch, pull_number, build_job_id, run_job_id)
  (SELECT DISTINCT ON (repo_id, commit) run_at, repo_id, commit, branch, pull_number, build_job_id, run_job_id
   FROM benchmarks);
