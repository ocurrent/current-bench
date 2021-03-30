open! Prelude
open Components

type testMetrics = {
  name: string,
  commit: string,
  metrics: Belt.Map.String.t<float>,
}

@module("../icons/branch.svg") external branchIcon: string = "default"

let groupByTestName = (acc, item: testMetrics, idx) => {
  let go = vOpt => {
    let idxs = switch vOpt {
    | Some(idxs) => idxs
    | None => Belt.Set.Int.empty
    }
    Some(Belt.Set.Int.add(idxs, idx))
  }
  Belt.Map.String.update(acc, item.name, go)
}

let decodeMetricValue = json => {
  switch Js.Json.classify(json) {
  | JSONNumber(n) => n
  | JSONArray([]) => 0.0
  | JSONArray(ns) =>
    Belt.Array.get(ns, 0)->Belt.Option.getExn->Js.Json.decodeNumber->Belt.Option.getExn
  | _ => invalid_arg("Invalid metric value: " ++ Js.Json.stringify(json))
  }
}

let collectMetricsByKey = (
  ~metricName,
  items: array<testMetrics>,
  selection: Belt.Set.Int.t,
): array<array<float>> => {
  let data = Belt.Array.makeUninitializedUnsafe(Belt.Set.Int.size(selection))
  Belt.Set.Int.reduce(selection, 0, (i, idx) => {
    let item: testMetrics = Belt.Array.getExn(items, idx)
    let metricWithIndex = [idx->float_of_int, item.metrics->Belt.Map.String.getExn(metricName)]
    Belt.Array.setExn(data, i, metricWithIndex)
    i + 1
  })->ignore
  data
}

let groupDataByMetric = (items: array<testMetrics>, selection: Belt.Set.Int.t): Belt.Map.String.t<
  array<array<float>>,
> => {
  open Belt

  let addMetricValue = (selectionIdx, acc, metricName, metricValue) => {
    let x = selectionIdx->float_of_int
    let y = metricValue
    let row = [x, y]
    BeltHelpers.MapString.addToArray(acc, metricName, row)
  }

  let groupByMetric = (acc, selectionIdx) => {
    let testMetrics = Array.getExn(items, selectionIdx)
    testMetrics.metrics->Map.String.reduce(acc, addMetricValue(selectionIdx))
  }

  selection->Set.Int.reduce(Map.String.empty, groupByMetric)
}

let calcDelta = (a, b) => {
  let n = if b == 0.0 {
    0.0
  } else {
    let n = (b -. a) /. b *. 100.
    a < b ? -.n : abs_float(n)
  }
  n
}

let deltaToString = n =>
  if n > 0.0 {
    "+" ++ n->Js.Float.toFixedWithPrecision(~digits=2) ++ "%"
  } else {
    n->Js.Float.toFixedWithPrecision(~digits=2) ++ "%"
  }

let renderMetricOverviewRow = (
  ~repoId,
  ~comparison as (comparisonTimeseries, _comparisonMetadata)=([], []),
  ~testName,
  ~metricName,
  (timeseries, metadata),
) => {
  if Belt.Array.length(timeseries) == 0 {
    React.null
  } else {
    let last_value = BeltHelpers.Array.lastExn(timeseries)[1]
    let (vsMasterAbs, vsMasterRel) = switch BeltHelpers.Array.last(comparisonTimeseries) {
    | Some(lastComparisionRow) =>
      let lastComparisonY = lastComparisionRow[1]
      (
        Js.Float.toFixedWithPrecision(~digits=2)(lastComparisonY),
        calcDelta(last_value, lastComparisonY)->deltaToString,
      )
    | _ => ("NA", "NA")
    }

    <Table.Row key=metricName>
      <Table.Col>
        <a href={"#line-graph-" ++ testName ++ "-" ++ metricName}> {Rx.text(metricName)} </a>
      </Table.Col>
      <Table.Col sx=[Sx.text.right]>
        {Rx.text(last_value->Js.Float.toFixedWithPrecision(~digits=2))}
      </Table.Col>
      <Table.Col sx=[Sx.text.right]> {Rx.text(vsMasterAbs)} </Table.Col>
      <Table.Col sx=[Sx.text.right]> {Rx.text(vsMasterRel)} </Table.Col>
    </Table.Row>
  }
}

let getMetricDelta = (
  ~comparison as (comparisonTimeseries, _comparisonMetadata)=([], []),
  (timeseries, _metadata),
) => {
  if Belt.Array.length(timeseries) == 0 {
    None
  } else {
    let last_value = BeltHelpers.Array.lastExn(timeseries)[1]

    switch BeltHelpers.Array.last(comparisonTimeseries) {
    | Some(lastComparisionRow) =>
      let lastComparisonY = lastComparisionRow[1]
      Some(calcDelta(last_value, lastComparisonY))
    | _ => None
    }
  }
}

@react.component
let make = (
  ~repoId,
  ~pullNumber,
  ~testName,
  ~comparison=Belt.Map.String.empty,
  ~dataByMetricName,
) => {
  let metric_table = {
    <Table sx=[Sx.mb.xl2]>
      <thead>
        <tr className={Sx.make([Sx.h.xl2])}>
          <th> {React.string("Metric")} </th>
          <th> {React.string("Last PR value")} </th>
          <th> {React.string("Last master value")} </th>
          <th> {React.string("Delta")} </th>
        </tr>
      </thead>
      <tbody>
        {dataByMetricName
        ->Belt.Map.String.mapWithKey(metricName => {
          let (comparisonTimeseries, comparisonMetadata) = Belt.Map.String.getWithDefault(
            comparison,
            metricName,
            ([], []),
          )
          renderMetricOverviewRow(
            ~repoId,
            ~comparison=(comparisonTimeseries, comparisonMetadata),
            ~testName,
            ~metricName,
          )
        })
        ->Belt.Map.String.valuesToArray
        ->Rx.array}
      </tbody>
    </Table>
  }

  let metric_graphs = React.useMemo1(() => {
    dataByMetricName
    ->Belt.Map.String.mapWithKey((metricName, (timeseries, metadata)) => {
      let (comparisonTimeseries, comparisonMetadata) = Belt.Map.String.getWithDefault(
        comparison,
        metricName,
        ([], []),
      )

      let timeseries = Belt.Array.concat(comparisonTimeseries, timeseries)
      let metadata = Belt.Array.concat(comparisonMetadata, metadata)

      let xTicks = Belt.Array.reduceWithIndex(timeseries, Belt.Map.Int.empty, (acc, row, index) => {
        // Use indexed instead of dates. This allows us to map to commits.
        Belt.Array.set(row, 0, float_of_int(index))->ignore
        let tick = switch Belt.Array.get(metadata, index) {
        | Some(xMetadata) =>
          let xValue = xMetadata["commit"]
          DataHelpers.trimCommit(xValue)
        | None => "Unknown"
        }
        Belt.Map.Int.set(acc, index, tick)
      })

      let annotations = if Belt.Array.length(comparisonTimeseries) > 0 {
        let firstPullX = Belt.Array.length(comparisonTimeseries)
        [
          {
            "series": "value",
            "x": firstPullX,
            "icon": branchIcon,
            "text": "Open PR on GitHub",
            "width": 21,
            "height": 21,
            "clickHandler": (_annotation, _point, _dygraph, _event) => {
              switch pullNumber {
              | Some(pullNumber) =>
                DomHelpers.window->DomHelpers.windowOpen(
                  "https://github.com/" ++ repoId ++ "/pull/" ++ string_of_int(pullNumber),
                )
              | None => ()
              }
            },
          },
        ]
      } else {
        []
      }
      let delta = getMetricDelta(
        ~comparison=(comparisonTimeseries, comparisonMetadata),
        (timeseries, metadata),
      )
      let delta = Belt.Option.map(delta, delta =>
        delta == 0.0 ? "Same as master" : deltaToString(delta) ++ " vs master"
      )

      <div key=metricName>
        {Topbar.anchor(~id="line-graph-" ++ testName ++ "-" ++ metricName)}
        <LineGraph
          onXLabelClick={AppHelpers.goToCommitLink(~repoId)}
          title=metricName
          subTitle=?delta
          xTicks
          data={timeseries->Belt.Array.sliceToEnd(-20)}
          annotations
          labels=["idx", "value"]
        />
      </div>
    })
    ->Belt.Map.String.valuesToArray
    ->Rx.array
  }, [dataByMetricName])

  <details className={Sx.make([Sx.w.full])} open_=true>
    <summary
      className={Sx.make([
        Sx.mb.xl,
        Sx.px.lg,
        Sx.py.md,
        Sx.pointer,
        Sx.rounded.sm,
        Sx.border.xs,
        Sx.border.color(Sx.gray400),
        Sx.bg.color(Sx.gray200),
      ])}>
      <Text sx=[Sx.w.auto, Sx.text.md, Sx.text.bold, Sx.text.color(Sx.gray900)]> testName </Text>
    </summary>
    {Belt.Map.String.isEmpty(comparison) ? Rx.null : metric_table}
    <div
      className={Sx.make([
        Sx.unsafe("display", "grid"),
        Sx.unsafe("gap", "32px"), // xl2
        Sx.unsafe("gridTemplateColumns", "repeat(auto-fit, minmax(400px, 1fr))"),
      ])}>
      metric_graphs
    </div>
  </details>
}
