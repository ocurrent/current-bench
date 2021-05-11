-- WIP
select
  run_at,
  repo_id,
  commit,
  branch,
  pull_number,
  benchmark_name,
  duration,
  build_job_id,
  run_job_id,
  json_build_object(
    'results', json_agg(
      json_build_object(
        'name', test_name,
        'metrics', metrics
      )
    )
  ) as output
from benchmarks
where
  repo_id = 'mirage/index' and
  commit = '0e8b2050d9a74980d457a2b5b91897dd09a3e8de'
group by 
  run_at,
  repo_id,
  commit,
  branch,
  pull_number,
  benchmark_name,
  duration,
  build_job_id,
  run_job_id
limit 10;