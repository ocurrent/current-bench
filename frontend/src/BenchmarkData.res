open Belt

type timeseries = array<LineGraph.DataRow.t>
type byMetricName = Map.String.t<(timeseries, array<{"commit": string, "runAt": Js.Date.t, "units": LineGraph.DataRow.units}>)>
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
  ~units: LineGraph.DataRow.units
) => {
  // Unwrap
  let byMetricName = Map.String.getWithDefault(byTestName, testName, Map.String.empty)
  let (timeseries, metadata) = Map.String.getWithDefault(byMetricName, metricName, ([], []))

  // Update
  let row = LineGraph.DataRow.with_date(runAt, value)
  let timeseries = BeltHelpers.Array.add(timeseries, row)
  let metadata = BeltHelpers.Array.add(metadata, {"commit": commit, "runAt": runAt, "units": units})

  // Wrap
  let byMetricName = Map.String.set(byMetricName, metricName, (timeseries, metadata))
  let byTestName = Map.String.set(byTestName, testName, byMetricName)
  byTestName
}
