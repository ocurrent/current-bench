CREATE VIEW bench_workers AS
  SELECT * FROM (
    SELECT worker, docker_image, repo_id, pull_number, MAX(run_at) AS run_at
    FROM benchmark_metadata
    GROUP BY worker, docker_image, repo_id, pull_number
    ORDER BY MAX(run_at) DESC
  ) AS q;
