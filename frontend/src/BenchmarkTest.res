open! Prelude
open Components

@module("../icons/branch.svg") external branchIcon: string = "default"

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
    "+" ++ n->Js.Float.toPrecisionWithPrecision(~digits=6) ++ "%"
  } else {
    n->Js.Float.toPrecisionWithPrecision(~digits=6) ++ "%"
  }

let renderMetricOverviewRow = (
  ~comparison as (comparisonTimeseries: array<LineGraph.DataRow.t>, _comparisonMetadata)=([], []),
  ~testName,
  ~metricName,
  (timeseries, _),
) => {
  if Belt.Array.length(timeseries) == 0 {
    React.null
  } else {
    let last_value = BeltHelpers.Array.lastExn(timeseries)->LineGraph.DataRow.toFloat
    let (vsMasterAbs, vsMasterRel) = switch BeltHelpers.Array.last(comparisonTimeseries) {
    | Some(lastComparisionRow) =>
      let lastComparisonY = lastComparisionRow->LineGraph.DataRow.toFloat
      (
        Js.Float.toPrecisionWithPrecision(~digits=6)(lastComparisonY),
        calcDelta(last_value, lastComparisonY)->deltaToString,
      )
    | _ => ("NA", "NA")
    }

    <Table.Row key=metricName>
      <Table.Col>
        <a href={"#line-graph-" ++ testName ++ "-" ++ metricName}> {Rx.text(metricName)} </a>
      </Table.Col>
      <Table.Col sx=[Sx.text.right]>
        {Rx.text(last_value->Js.Float.toPrecisionWithPrecision(~digits=6))}
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
    let last_value = BeltHelpers.Array.lastExn(timeseries)->LineGraph.DataRow.toFloat

    switch BeltHelpers.Array.last(comparisonTimeseries) {
    | Some(lastComparisionRow) =>
      let lastComparisonY = lastComparisionRow->LineGraph.DataRow.toFloat
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
  ~dataByMetricName: Belt.Map.String.t<(array<LineGraph.DataRow.t>, 'a)>,
) => {
  let metric_table = {
    <Table sx=[Sx.mb.xl2]>
      <thead>
        <tr className={Sx.make([Sx.h.xl2])}>
          <th> {React.string("Metric")} </th>
          <th> {React.string("Last PR value")} </th>
          <th> {React.string("Last main value")} </th>
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

      let timeseries: array<LineGraph.DataRow.t> = Belt.Array.concat(
        comparisonTimeseries,
        timeseries,
      )
      let metadata = Belt.Array.concat(comparisonMetadata, metadata)

      let xTicks = Belt.Array.reduceWithIndex(timeseries, Belt.Map.Int.empty, (acc, row, index) => {
        // Use indexed instead of dates. This allows us to map to commits.
        LineGraph.DataRow.set_index(index, row)
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
        delta == 0.0 ? "Same as main" : deltaToString(delta) ++ " vs main"
      )

      <div key=metricName>
        {Topbar.anchor(~id="line-graph-" ++ testName ++ "-" ++ metricName)}
        <LineGraph
          onXLabelClick={AppHelpers.goToCommitLink(~repoId)}
          title=metricName
          subTitle=?delta
          xTicks
          data={timeseries->Belt.Array.sliceToEnd(-20)}
          units={(metadata->BeltHelpers.Array.lastExn)["units"]}
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
