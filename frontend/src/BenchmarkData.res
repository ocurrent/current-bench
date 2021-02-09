open Belt

module PullNumberId = Id.MakeComparable({
  type t = option<int>
  let cmp = (a, b) => Pervasives.compare(a, b)
})

type timeseries = array<array<float>>
type byMetricName = Map.String.t<(timeseries, array<{"commit": string, "runAt": Js.Date.t}>)>
type byTestName = Map.String.t<byMetricName>
type byPullNumber = Map.t<PullNumberId.t, byTestName, PullNumberId.identity>
type t = byPullNumber

let empty: t = Map.make(~id=module(PullNumberId))

let add = (
  byPullNumber: t,
  ~pullNumber,
  ~testName,
  ~metricName,
  ~runAt: Js.Date.t,
  ~commit,
  ~value: float,
) => {
  // Unwrap
  let byTestName = Map.getWithDefault(byPullNumber, pullNumber, Map.String.empty)
  let byMetricName = Map.String.getWithDefault(byTestName, testName, Map.String.empty)
  let (timeseries, metadata) = Map.String.getWithDefault(byMetricName, metricName, ([], []))

  // Update
  let row = [(Obj.magic(runAt): float), value]
  let timeseries = BeltHelpers.Array.push(timeseries, row)
  let metadata = BeltHelpers.Array.push(metadata, {"commit": commit, "runAt": runAt})

  // Wrap
  let byMetricName = Map.String.set(byMetricName, metricName, (timeseries, metadata))
  let byTestName = Map.String.set(byTestName, testName, byMetricName)
  let byPullNumber = Map.set(byPullNumber, pullNumber, byTestName)
  byPullNumber
}

let forPullNumber = (byPullNumber: t, pullNumber) => {
  Map.getWithDefault(byPullNumber, pullNumber, Map.String.empty)
}

let forTestName = (byTestName: byTestName, testName) => {
  Map.String.getWithDefault(byTestName, testName, Map.String.empty)
}

let forMetricName = (byMetricName: byMetricName, metricName) => {
  Map.String.getWithDefault(byMetricName, metricName, ([], []))
}
