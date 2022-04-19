let defaultBenchmarkName = "default"

// We use a NaN value to fill in values for missing commits
let missingValue = [Js.Float._NaN, Js.Float._NaN, Js.Float._NaN]

// Get commits sorted by runAt timestamp
let sortedCommitsByRunAt = dataByTestName => {
  dataByTestName
  ->Belt.Map.String.valuesToArray
  ->Belt.Array.map(((_, dataByMetricName)) => dataByMetricName->Belt.Map.String.valuesToArray)
  ->Belt.Array.concatMany
  ->Belt.Array.map(((_, md)) => md)
  ->Belt.Array.concatMany
  ->Belt.Array.reduce(Belt.Map.String.empty, (acc, md: LineGraph.DataRow.md) => {
    Belt.Map.String.set(acc, md.commit, md)
  })
  ->Belt.Map.String.valuesToArray
  ->Belt.SortArray.stableSortBy((a, b) =>
    compare(Js.Date.getTime(a.runAt), Js.Date.getTime(b.runAt))
  )
  ->Belt.Array.map(md => (md.commit, md.runAt, md.run_job_id))
}

// Fill in NaN values and add missing commit metadata
let addMissingCommits = (
  (metricTimeseries: BenchmarkData.timeseries, metricMetadata: BenchmarkData.metadata) as data,
  allCommits,
) => {
  let n = Belt.Array.length(allCommits)
  switch Belt.Array.length(metricTimeseries) < n {
  | false => data

  | true => {
      let filledTimeseries = allCommits->Belt.Array.map(((commit, _, _)) =>
        switch metricMetadata->Belt.Array.getIndexBy(md => md.commit == commit) {
        | Some(idx) => Belt.Array.getExn(metricTimeseries, idx)
        | None => missingValue
        }
      )
      // We use the last metadata item and use that as a template to create
      // entries for missing commits. commit, runAt, lines and run_job_id are
      // overwritten.  Other metadata like units, trend, description are the
      // same as metadata in the last commit.
      let templateMetadata = BeltHelpers.Array.lastExn(metricMetadata)
      let filledMetadata = allCommits->Belt.Array.map(((commit, runAt, run_job_id)) => {
        switch metricMetadata->Belt.Array.getBy(md => md.commit == commit) {
        | Some(metadata) => metadata
        | _ => {
            ...templateMetadata,
            runAt: runAt,
            run_job_id: run_job_id,
            commit: commit,
            lines: []->Belt.List.fromArray,
          }
        }
      })
      (filledTimeseries, filledMetadata)
    }
  }
}

// Fill in values and metadata for all missing commits across all metrics in all tests
let fillMissingValues = dataByTestName => {
  let allCommitsByRunAt = sortedCommitsByRunAt(dataByTestName)
  dataByTestName->Belt.Map.String.map(((test_index, dataByMetricName)) => (
    test_index,
    dataByMetricName->Belt.Map.String.map(metricData =>
      addMissingCommits(metricData, allCommitsByRunAt)
    ),
  ))
}

let metricNames = dataByTestName =>
  dataByTestName->Belt.Map.String.map(((_, dataByMetricName)) => {
    dataByMetricName->Belt.Map.String.keysToArray
  })

// Add dummy values for metrics missing in the comparison metrics data
let addMissingComparisonMetrics = (comparisonBenchmarkDataByTestName, benchmarkDataByTestName) => {
  let allComparisonCommitsByRunAt = sortedCommitsByRunAt(comparisonBenchmarkDataByTestName)
  let n = allComparisonCommitsByRunAt->Belt.Array.length
  let benchmarkMetricNames = metricNames(benchmarkDataByTestName)
  let comparisonMetricNames = metricNames(comparisonBenchmarkDataByTestName)

  let allMetricNames =
    benchmarkMetricNames->Belt.Map.String.mapWithKey((testName, metricNames) =>
      metricNames
      ->Belt.Set.String.fromArray
      ->Belt.Set.String.mergeMany(
        comparisonMetricNames->Belt.Map.String.getWithDefault(testName, []),
      )
      ->Belt.Set.String.toArray
    )

  let comparisonBenchmarkDataByTestName = allMetricNames->Belt.Map.String.mapWithKey((
    testName,
    metricNames,
  ) => {
    let (testIndex, testData) = Belt.Map.String.getWithDefault(
      comparisonBenchmarkDataByTestName,
      testName,
      (0, Belt.Map.String.empty),
    )

    let testData =
      metricNames
      ->Belt.Array.map(metricName => {
        let metricData = Belt.Map.String.get(testData, metricName)
        let metricData = switch metricData {
        | Some(metricData) => metricData
        | None => {
            let ts = Belt.Array.range(0, n - 1)->Belt.Array.map(_ => missingValue)
            let md = allComparisonCommitsByRunAt->Belt.Array.map(((
              commit,
              runAt,
              run_job_id,
            )): LineGraph.DataRow.md => {
              commit: commit,
              runAt: runAt,
              run_job_id: run_job_id,
              lines: []->Belt.List.fromArray,
              description: "",
              trend: "",
              units: "",
            })
            (ts, md)
          }
        }
        (metricName, metricData)
      })
      ->Belt.Map.String.fromArray
    (testIndex, testData)
  })

  comparisonBenchmarkDataByTestName
}
