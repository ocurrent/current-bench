open Belt

type timeseries = array<LineGraph.DataRow.t>
type byMetricName = Map.String.t<(
  timeseries,
  array<{
    "commit": string,
    "runAt": Js.Date.t,
    "units": LineGraph.DataRow.units,
    "description": string
  }>,
)>
type byTestName = Map.String.t<(int, byMetricName)>
type t = byTestName

let empty: t = Map.String.empty

let add = (
  byTestName: t,
  ~testName,
  ~testIndex,
  ~metricName,
  ~runAt: Js.Date.t,
  ~commit,
  ~value: LineGraph.DataRow.value,
  ~units: LineGraph.DataRow.units,
  ~description,
) => {
  // Unwrap
  let (_, byMetricName) = Map.String.getWithDefault(byTestName, testName, (0, Map.String.empty))
  let (timeseries, metadata) = Map.String.getWithDefault(byMetricName, metricName, ([], []))

  // Update
  let timeseries = BeltHelpers.Array.add(timeseries, [Obj.magic(Belt.Array.length(timeseries)), value])
  let metadata = BeltHelpers.Array.add(
    metadata,
    {"commit": commit, "runAt": runAt, "units": units, "description": description},
  )

  // Wrap
  let byMetricName = Map.String.set(byMetricName, metricName, (timeseries, metadata))
  let byTestName = Map.String.set(byTestName, testName, (testIndex, byMetricName))
  byTestName
}
