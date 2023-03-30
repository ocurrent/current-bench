module BenchmarkMetrics = %graphql(`
fragment BenchmarkMetrics on benchmarks {
  version
  run_at
  commit
  test_name
  test_index
  metrics
  run_job_id
  worker
  docker_image
  branch
}
`)

module GetBenchmarks = %graphql(`
query ($repoId: String!,
       $pullNumber: Int,
       $branch: String,
       $defaultBranch: String!,
       $isMaster: Boolean!,
       $worker: String,
       $dockerImage: String,
       $benchmarkName: String!,
       $startDate: timestamp!,
       $endDate: timestamp!,
       $comparisonLimit: Int!) {
  benchmarks:
    benchmarks(where: {_and: [{pull_number: {_eq: $pullNumber}},
                              {pull_number: {_is_null: $isMaster}},
                              {branch: {_eq: $branch}},
                              {repo_id: {_eq: $repoId}},
                              {worker: {_eq: $worker}},
                              {docker_image: {_eq: $dockerImage}},
                              {benchmark_name: {_eq: $benchmarkName}},
                              {run_at: {_gte: $startDate}},
                              {run_at: {_lt: $endDate}}]},
               order_by: [{run_at: asc}]) {
    ...BenchmarkMetrics
  }
  comparisonBenchmarks:
    benchmarks(where: {_and: [{pull_number: {_is_null: true}},
                              {branch: {_eq: $defaultBranch}},
                              {repo_id: {_eq: $repoId}},
                              {worker: {_eq: $worker}},
                              {docker_image: {_eq: $dockerImage}},
                              {benchmark_name: {_eq: $benchmarkName}},
                              {run_at: {_gte: $startDate}},
                              {run_at: {_lt: $endDate}}]},
               limit: $comparisonLimit,
               order_by: [{run_at: desc}]) {
    ...BenchmarkMetrics
  }
}
`)

module GetWorkers = %graphql(`
query ($repoId: String!,
       $pullNumber: Int,
       $isMain: Boolean!) {
  workers:
    bench_workers(where: {_and: [{pull_number: {_eq: $pullNumber}},
                                 {pull_number: {_is_null: $isMain}},
                                 {repo_id: {_eq: $repoId}}]}) {
      worker
      docker_image
  }
}
`)
