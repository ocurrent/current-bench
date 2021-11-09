open! Prelude
open Components

type testMetrics = {
  name: string,
  commit: string,
  metrics: array<LineGraph.DataRow.metric>,
}

@module("../icons/branch.svg") external branchIcon: string = "default"

let isSize = (x) => Js.Re.exec_(%re("/(gb|mb|kb|bytes)\w*/i"), x)
  ->Belt.Option.isSome

let formatSize = (value, units) => {
  let str = Js.Float.toExponential(value)

  // separate exponent into integral and exponent
  // For example if the number is 314.00 then the exponential looks like
  // 314.00 -> 3.14e+2
  // where exp_ == 2
  // and integral == 3.14
  // the unit only rolls over if ceiling(n / 3) > 0
  // so 3.14e+2 would clearly not have any change in units 
  // as ceiling(2 / 3) == 0
  // multiply integral (3.14) with 10^(mod(exp_, 3))
  // in order to maintain correctness with the unit

  let exp_ = Js.String.split("e", str) -> Belt.Array.getExn(1)
  let sign = Js.String.get(exp_, 0)
  let exp_ = (Js.String.get(exp_, 1)
      ->Belt.Int.fromString
      ->Belt.Option.getExn)
  let exp = exp_ / 3
  let integral = Js.String.split("e", str) 
    -> Belt.Array.getExn(0)
    -> Belt.Float.fromString
    -> Belt.Option.map((x) => x *. (Js.Math.pow_float(~base=10.0, ~exp=mod(exp_,3)->Belt.Int.toFloat)))
    -> Belt.Option.getExn
  Js.log(integral)
  let newValue = integral

  let unitArr = ["bytes", "kb", "mb", "gb", "tb", "pb", "eb", "zb", "yb"]
  let startIndex = Js.Re.exec_(%re("/(gb|mb|kb|bytes)\w*/i"), units)
    ->Belt.Option.getExn
    ->Js.Re.index
  let endIndex = startIndex + 2
  let oldStr = Js.String.substring(~from=startIndex, ~to_=endIndex, units)
  let newUnit = switch sign {
    | "+" => {
      let index_ = Js.Array.findIndex(x => x == oldStr, unitArr)
      let newStr = Belt.Array.getExn(unitArr, index_ + exp)
      Js.String.replace(oldStr, newStr, units)
    }
    | "-" => {
      let index_ = Js.Array.findIndex(x => x == oldStr, unitArr)
      let newStr = Belt.Array.getExn(unitArr, index_ - exp)
      Js.String.replace(oldStr, newStr, units)
    }
  }
  (newValue, newUnit)
}

let decodeMetricValue = (json, units): (LineGraph.DataRow.value, Js.String.t) => {
  switch Js.Json.classify(json) {
  | JSONNumber(n) => {
    if isSize(units) {
      let (v, u) = formatSize(n, units)
      (LineGraph.DataRow.single(v), u)
    } else {
      (LineGraph.DataRow.single(n), units)
    }
  }
  | JSONArray([]) => (LineGraph.DataRow.single(nan), units)
  | JSONArray(xs) =>
    let xs = xs->Belt.Array.map(x => x->Js.Json.decodeNumber->Belt.Option.getExn)
    (LineGraph.DataRow.many(xs), units)
  | JSONString(val) =>
    switch Js.String2.match_(
      val,
      %re("/^([0-9]+\.*[0-9]*)min([0-9]+\.*[0-9]*)s|([0-9]+\.*[0-9]*)s$/"),
    ) {
    | Some([_, minutes, seconds]) =>
      if minutes == "" {
        let n = Js.Float.fromString(seconds)
        (LineGraph.DataRow.single(n), units)
      } else {
        let n = Js.Float.fromString(minutes) *. 60.0 +. Js.Float.fromString(seconds)
        (LineGraph.DataRow.single(n), units)
      }
    | _ => invalid_arg("Invalid metric value:" ++ Js.Json.stringify(json))
    }
  | _ => invalid_arg("Invalid metric value: " ++ Js.Json.stringify(json))
  }
}

let decodeMetric = (data): LineGraph.DataRow.metric => {
    let name = (Js.Dict.get(data, "name")->Belt.Option.getExn->Js.Json.decodeString->Belt.Option.getExn)
    let units_ = (Js.Dict.get(data, "units")->Belt.Option.getExn->Js.Json.decodeString->Belt.Option.getExn)
    let (value, units) = decodeMetricValue(Js.Dict.get(data, "value")->Belt.Option.getExn, units_)
  {
    name: name,
    units: units,
    value: value,
  }
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
