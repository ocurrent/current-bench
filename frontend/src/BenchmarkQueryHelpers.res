module BenchmarkMetrics = %graphql(`
fragment BenchmarkMetrics on benchmarks {
  version
  run_at
  commit
  test_name
  test_index
  metrics
}
`)

module GetBenchmarks = %graphql(`
query ($repoId: String!,
       $pullNumber: Int,
       $isMaster: Boolean!,
       $benchmarkName: String,
       $isDefaultBenchmark: Boolean!,
       $startDate: timestamp!,
       $endDate: timestamp!,
       $comparisonLimit: Int!) {
  benchmarks:
    benchmarks(where: {_and: [{pull_number: {_eq: $pullNumber}},
                              {pull_number: {_is_null: $isMaster}},
                              {repo_id: {_eq: $repoId}},
                              {benchmark_name: {_is_null: $isDefaultBenchmark,
                                                _eq: $benchmarkName}},
                              {run_at: {_gte: $startDate}},
                              {run_at: {_lt: $endDate}}]},
               order_by: [{run_at: asc}]) {
    ...BenchmarkMetrics
  }
  comparisonBenchmarks:
    benchmarks(where: {_and: [{pull_number: {_is_null: true}},
                              {repo_id: {_eq: $repoId}},
                              {benchmark_name: {_is_null: $isDefaultBenchmark, _eq: $benchmarkName}},
                              {run_at: {_gte: $startDate}},
                              {run_at: {_lt: $endDate}}]},
               limit: $comparisonLimit,
               order_by: [{run_at: desc}]) {
    ...BenchmarkMetrics
  }
}
`)