open! Prelude
open Components

type testMetrics = {
  name: string,
  commit: string,
  metrics: Belt.Map.String.t<float>,
}

let commitUrl = commit => `https://github.com/mirage/index/commit/${commit}`
let goToCommitLink = commit => {
  let openUrl: string => unit = %raw(`function (url) { window.open(url, "_blank") }`)
  openUrl(commitUrl(commit))
}

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

let calcDeltaStr = (a, b) => {
  let n = if b == 0.0 {
    0.0
  } else {
    let n = (b -. a) /. b *. 100.
    a < b ? -.n : abs_float(n)
  }
  if n > 0.0 {
    "+" ++ n->Js.Float.toFixedWithPrecision(~digits=2) ++ "%"
  } else {
    n->Js.Float.toFixedWithPrecision(~digits=2) ++ "%"
  }
}

let renderMetricOverviewRow = (
  ~comparison as (comparisonTimeseries, _comparisonMetadata)=([], []),
  metricName,
  (timeseries, metadata),
) => {
  if Belt.Array.length(timeseries) == 0 {
    React.null
  } else {
    let last_value = BeltHelpers.Array.lastExn(timeseries)[1]
    let commit = BeltHelpers.Array.lastExn(metadata)["commit"]->DataHelpers.trimCommit

    let (vsMasterAbs, vsMasterRel) = switch BeltHelpers.Array.last(comparisonTimeseries) {
    | Some(lastComparisionRow) =>
      let lastComparisonY = lastComparisionRow[1]
      (
        Js.Float.toFixedWithPrecision(~digits=2)(lastComparisonY),
        calcDeltaStr(last_value, lastComparisonY),
      )
    | _ => ("NA", "NA")
    }

    <Table.Row key=metricName>
      <Table.Col> {Rx.text(metricName)} </Table.Col>
      <Table.Col> <Link target="_blank" href={commitUrl(commit)} text=commit /> </Table.Col>
      <Table.Col> {Rx.text(last_value->Js.Float.toFixedWithPrecision(~digits=2))} </Table.Col>
      <Table.Col sx=[Sx.text.right]> {Rx.text(vsMasterAbs)} </Table.Col>
      <Table.Col sx=[Sx.text.right]> {Rx.text(vsMasterRel)} </Table.Col>
    </Table.Row>
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
    <Table>
      <thead>
        <tr className={Sx.make([Sx.h.xl2])}>
          <th> {React.string("Metric")} </th>
          <th> {React.string("Last Commit")} </th>
          <th> {React.string("Last Value")} </th>
          <th> {React.string("Master Value")} </th>
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
            ~comparison=(comparisonTimeseries, comparisonMetadata),
            metricName,
          )
        })
        ->Belt.Map.String.valuesToArray
        ->Rx.array}
      </tbody>
    </Table>
  }

  let graph_metrics = React.useMemo1(() => {
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
            "icon": "/branch.svg",
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
      (metricName, xTicks, timeseries->Belt.Array.sliceToEnd(-20), annotations)
    })
    ->Belt.Map.String.valuesToArray
  }, [dataByMetricName])

  <details className={Sx.make([Sx.w.full])} open_=true>
    <summary className={Sx.make([Sx.pointer])}>
      <Text sx=[Sx.text.xl2, Sx.text.bold]> {Rx.text(testName)} </Text>
    </summary>
    <Column sx=[Sx.mt.xl]>
      metric_table
      <Flex wrap=true>
        {graph_metrics
        ->Belt.Array.map(((metricName, xTicks, data, annotations)) =>
          <LineGraph
            key=metricName
            title=metricName
            xTicks
            data
            annotations
            labels=["idx", "value"]
            onXLabelClick=goToCommitLink
          />
        )
        ->Rx.array}
      </Flex>
    </Column>
  </details>
}
