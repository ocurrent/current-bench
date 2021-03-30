open Belt

type timeseries = array<LineGraph.DataRow.t>
type byMetricName = Map.String.t<(timeseries, array<{"commit": string, "runAt": Js.Date.t}>)>
type byTestName = Map.String.t<byMetricName>
type t = byTestName

let empty: t = Map.String.empty

let add = (
  byTestName: t,
  ~testName,
  ~metricName,
  ~runAt: Js.Date.t,
  ~commit,
  ~value: LineGraph.DataRow.value,
) => {
  // Unwrap
  let byMetricName = Map.String.getWithDefault(byTestName, testName, Map.String.empty)
  let (timeseries, metadata) = Map.String.getWithDefault(byMetricName, metricName, ([], []))

  // Update
  let row = LineGraph.DataRow.with_date(runAt, value)
  let timeseries = BeltHelpers.Array.push(timeseries, row)
  let metadata = BeltHelpers.Array.push(metadata, {"commit": commit, "runAt": runAt})

  // Wrap
  let byMetricName = Map.String.set(byMetricName, metricName, (timeseries, metadata))
  let byTestName = Map.String.set(byTestName, testName, byMetricName)
  byTestName
}

let forTestName = (byTestName: byTestName, testName) => {
  Map.String.getWithDefault(byTestName, testName, Map.String.empty)
}

let forMetricName = (byMetricName: byMetricName, metricName) => {
  Map.String.getWithDefault(byMetricName, metricName, ([], []))
}
