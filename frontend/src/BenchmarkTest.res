open! Prelude
open Components
open MetricHierarchyHelpers

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

type metricRow = {
  delta: option<float>,
  last_value: option<float>,
  comparison_value: option<float>,
  trend: string,
}

let getRowData = (
  ~comparison as (comparisonTimeseries, _comparisonMetadata)=([], []),
  (timeseries, _metadata),
) => {
  if Belt.Array.length(timeseries) == 0 {
    let d = {delta: None, last_value: None, comparison_value: None, trend: ""}
    d
  } else {
    let last_value = BeltHelpers.Array.lastExn(timeseries)->LineGraph.DataRow.toValue
    let trend = BeltHelpers.Array.lastExn(_metadata)["trend"]

    switch BeltHelpers.Array.last(comparisonTimeseries) {
    | Some(lastComparisonRow) =>
      let lastComparisonY = lastComparisonRow->LineGraph.DataRow.toValue
      let d = {
        delta: Some(calcDelta(last_value, lastComparisonY)),
        comparison_value: Some(lastComparisonY),
        last_value: Some(last_value),
        trend: trend,
      }
      d
    | _ =>
      let d = {
        delta: None,
        last_value: Some(last_value),
        comparison_value: None,
        trend: trend,
      }
      d
    }
  }
}

let isFavourableDelta = row => {
  let ascending =
    row.trend == "higher-is-better"
      ? Some(true)
      : row.trend == "lower-is-better"
      ? Some(false)
      : None
  switch (row.delta, ascending) {
  | (Some(delta), Some(ascending)) => delta == 0. ? None : Some(delta > 0. == ascending)
  | _ => None
  }
}

let renderMetricOverviewRow = (
  ~comparison as (comparisonTimeseries: array<LineGraph.DataRow.t>, _comparisonMetadata)=([], []),
  ~testName,
  ~metricName,
  (timeseries, metadata),
) => {
  let row = getRowData(
    ~comparison=(comparisonTimeseries, _comparisonMetadata),
    (timeseries, metadata),
  )
  switch row.last_value {
  | None => React.null
  | Some(last_value) => {
      let (vsMasterAbs, vsMasterRel) = switch (row.comparison_value, row.delta) {
      | (Some(y), Some(delta)) => (
          Js.Float.toPrecisionWithPrecision(~digits=6)(y),
          delta->deltaToString,
        )
      | _ => ("NA", "NA")
      }
      let color = switch isFavourableDelta(row) {
      | Some(true) => Sx.green300
      | Some(false) => Sx.red300
      | None => Sx.black
      }
      <Table.Row key=metricName>
        <Table.Col>
          <a href={"#line-graph-" ++ testName ++ "-" ++ metricName}> {Rx.text(metricName)} </a>
        </Table.Col>
        <Table.Col sx=[Sx.text.right]>
          {Rx.text(last_value->Js.Float.toPrecisionWithPrecision(~digits=6))}
        </Table.Col>
        <Table.Col sx=[Sx.text.right]> {Rx.text(vsMasterAbs)} </Table.Col>
        <Table.Col sx=[Sx.text.right, Sx.text.color(color)]> {Rx.text(vsMasterRel)} </Table.Col>
      </Table.Row>
    }
  }
}

let makeAnnotation = (x, series, repoId, pullNumber) => {
  {
    "series": series,
    "x": x,
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
  }
}

let makeSubTitle = (row, description): LineGraph.elementOrString =>
  switch row.delta {
  | Some(delta) => {
      let subTitleText = delta == 0.0 ? "Same as main" : deltaToString(delta) ++ " vs main"
      switch (isFavourableDelta(row), delta == 0.0) {
      | (Some(val), false) =>
        let color = val ? Sx.green300 : Sx.red300
        let icon = delta > 0. ? Icon.upArrow : Icon.downArrow
        let elem =
          <span className={Sx.make([Sx.d.flex, Sx.flex.row, Sx.items.stretch])}>
            <span className={Sx.make([Sx.mr.md, Sx.text.color(color)])}> {icon} </span>
            <Text
              sx=[
                Sx.d.inlineBlock,
                Sx.leadingNone,
                Sx.text.sm,
                Sx.text.color(color),
                [Css.minHeight(#em(1.0))],
              ]>
              {subTitleText}
            </Text>
          </span>
        Element(elem)
      | _ => String(subTitleText)
      }
    }
  | _ => String(description)
  }

let getSeriesArrays = (data, comparison, metricName) => {
  let (comparisonTimeseries, comparisonMetadata) = Belt.Map.String.getWithDefault(
    comparison,
    metricName,
    ([], []),
  )
  let (t, m) = Belt.Map.String.getWithDefault(data, metricName, ([], []))
  let timeseries: LineGraph.DataRow.row = Belt.Array.concat(comparisonTimeseries, t)
  let metadata = Belt.Array.concat(comparisonMetadata, m)
  (timeseries, metadata, comparisonTimeseries, comparisonMetadata)
}

@react.component
let make = (
  ~repoId,
  ~pullNumber,
  ~testName,
  ~comparison=Belt.Map.String.empty,
  ~dataByMetricName: Belt.Map.String.t<(array<LineGraph.DataRow.t>, 'a)>,
  ~lastCommit,
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

  let metricNamesByPrefix = groupMetricNamesByPrefix(dataByMetricName)

  let renderedOverlays = Belt.HashSet.String.make(
    ~hintSize=metricNamesByPrefix->Belt.Map.String.keysToArray->Belt.Array.length,
  )

  let renderMetricGraph = metricName => {
    let overlayPrefix = getMetricPrefix(metricName)
    let isOverlayed = overlayPrefix->Belt.Option.isSome
    let skipRender =
      isOverlayed && renderedOverlays->Belt.HashSet.String.has(overlayPrefix->Belt.Option.getExn)
    if isOverlayed {
      renderedOverlays->Belt.HashSet.String.add(overlayPrefix->Belt.Option.getExn)
    }

    switch skipRender {
    | true => Rx.null
    | false =>
      let names = isOverlayed
        ? metricNamesByPrefix->Belt.Map.String.getExn(overlayPrefix->Belt.Option.getExn)
        : [metricName]
      let suffixes = isOverlayed
        ? names->Belt.Array.map(x => Js.String.split("/", x)[1])
        : [metricName]
      // FIXME: Validate that units are same on all the overlays? (ideally, in the current_bench_json.ml)
      let seriesArrays =
        names->Belt.Array.map(x => getSeriesArrays(dataByMetricName, comparison, x))
      let (_, metadata, comparisonTimeseries, _f) = seriesArrays[0]
      let mergedMetadata = isOverlayed
        ? seriesArrays->Belt.Array.map(((_, md, _, _)) => md)->Belt.Array.getExn(0)
        : metadata
      let tsArrays = seriesArrays->Belt.Array.map(((ts, _, _, _)) => ts)
      let xTicks = mergedMetadata->Belt.Array.reduceWithIndex(Belt.Map.Int.empty, (
        acc,
        m,
        index,
      ) => {
        Belt.Map.Int.set(acc, index, DataHelpers.trimCommit(m["commit"]))
      })
      let rows =
        seriesArrays->Belt.Array.map(((ts, md, comp_ts, comp_md)) =>
          getRowData(~comparison=(comp_ts, comp_md), (ts, md))
        )
      let subTitle: LineGraph.elementOrString = switch isOverlayed {
      | false =>
        let description = BeltHelpers.Array.lastExn(mergedMetadata)["description"]
        makeSubTitle(BeltHelpers.Array.lastExn(rows), description)
      | true => String("")
      }
      let units = (mergedMetadata->BeltHelpers.Array.lastExn)["units"]
      let lines = (mergedMetadata->BeltHelpers.Array.lastExn)["lines"]
      let run_job_id = (mergedMetadata->BeltHelpers.Array.lastExn)["run_job_id"]
      let labels = suffixes
      let firstPullX = Belt.Array.length(comparisonTimeseries)
      let annotations =
        firstPullX > 0
          ? labels->Belt.Array.map(x => makeAnnotation(firstPullX, x, repoId, pullNumber))
          : []
      let title = isOverlayed ? overlayPrefix->Belt.Option.getExn : metricName
      let oldMetrics = mergedMetadata->Belt.Array.every(m => {Some(m["commit"]) != lastCommit})
      let failedMetric = rows->Belt.Array.some(row =>
        switch row.last_value {
        | Some(value) => Js.Float.isNaN(value)
        | _ => false
        }
      )

      let onXLabelClick = AppHelpers.goToCommitLink(~repoId)
      let id = `line-graph-${testName}-${title}`

      <div key=metricName className={Sx.make(oldMetrics ? [Sx.opacity25] : [])}>
        {Topbar.anchor(~id)}
        <LineGraph
          onXLabelClick
          title
          subTitle
          xTicks
          dataSet=tsArrays
          units
          annotations
          labels
          lines
          run_job_id
          failedMetric
        />
      </div>
    }
  }

  let metric_graphs = React.useMemo2(() => {
    dataByMetricName->Belt.Map.String.keysToArray->Belt.Array.map(renderMetricGraph)->Rx.array
  }, (dataByMetricName, lastCommit))

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
        Sx.unsafe("gap", "2px"),
      ])}>
      metric_graphs
    </div>
  </details>
}
