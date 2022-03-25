let commitUrl = (~repoId, commit) => `https://github.com/${repoId}/commit/${commit}`
let pullUrl = (~repoId, ~pull) => `https://github.com/${repoId}/pull/${pull}`
let goToCommitLink = (~repoId, commit) => {
  let openUrl: string => unit = %raw(`function (url) { window.open(url, "_blank") }`)
  openUrl(commitUrl(~repoId, commit))
}

let pipelineUrl: string = %raw(`import.meta.env.VITE_OCAML_BENCH_PIPELINE_URL`)
let jobUrl = (~lines=?, jobId) => {
  let href = pipelineUrl ++ "/job/" ++ jobId
  switch lines {
  | Some(start, end) => href ++ `#L${Belt.Int.toString(start)}-L${Belt.Int.toString(end)}`
  | _ => href
  }
}

let defaultBenchmarkName = "default"

// Get commits sorted by runAt timestamp
let sortedCommitsByRunAt = dataByTestName => {
  dataByTestName
  ->Belt.Map.String.valuesToArray
  ->Belt.Array.map(((_, dataByMetricName)) => dataByMetricName->Belt.Map.String.valuesToArray)
  ->Belt.Array.concatMany
  ->Belt.Array.map(((_, md)) => md)
  ->Belt.Array.concatMany
  ->Belt.Array.reduce(Belt.Map.String.empty, (acc, md) => {
    Belt.Map.String.set(acc, md["commit"], md)
  })
  ->Belt.Map.String.valuesToArray
  ->Belt.SortArray.stableSortBy((a, b) =>
    compare(Js.Date.getTime(a["runAt"]), Js.Date.getTime(b["runAt"]))
  )
  ->Belt.Array.map(md => (md["commit"], md["runAt"], md["run_job_id"]))
}

// Fill in NaN values and add missing commit metadata
let addMissingCommits = ((metricTimeseries, metricMetadata) as data, allCommits) => {
  let n = Belt.Array.length(allCommits)
  switch Belt.Array.length(metricTimeseries) < n {
  | false => data

  | true => {
      // We use a NaN value to fill in values for missing commits
      let missingValue = [Js.Float._NaN, Js.Float._NaN, Js.Float._NaN]
      let filledTimeseries = allCommits->Belt.Array.map(((commit, _, _)) =>
        switch metricMetadata->Belt.Array.getIndexBy(md => md["commit"] == commit) {
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
        Js.Obj.assign(Js.Obj.empty(), templateMetadata)->Js.Obj.assign({
          "commit": commit,
          "runAt": runAt,
          "run_job_id": run_job_id,
          "lines": [],
        })
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
