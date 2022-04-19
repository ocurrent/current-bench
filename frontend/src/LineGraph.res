open AppHelpers
open Components

type graph
type annotation
type point
type event

let computeStdDev = (~mean, xs) => {
  let n = Array.length(xs)
  let var = xs->Belt.Array.reduce(0., (acc, x) => {
    let y = x -. mean
    acc +. y *. y
  })
  switch n > 1 {
  | true => sqrt(var /. float_of_int(n - 1))
  | _ => var
  }
}

let computeMean = xs => {
  if Array.length(xs) == 0 {
    None
  } else {
    let (total, count) = Array.fold_left(
      ((total, count), x) => Js.Float.isNaN(x) ? (total, count) : (total +. x, count +. 1.),
      (0., 0.),
      xs,
    )
    Some(total /. count)
  }
}

let computeStats = xs => {
  if Array.length(xs) == 0 {
    None
  } else {
    let (min, max, total, count) = Array.fold_left(((min, max, total, count), x) => {
      let min = x < min ? x : min
      let max = x > max ? x : max
      let total = total +. x
      let count = count +. 1.
      (min, max, total, count)
    }, (xs[0], xs[0], 0., 0.), xs)
    Some((min, max, total /. count))
  }
}

module DataRow = {
  type name = string
  type units = string
  type lines = list<(int, int)>
  type value = float
  type metric = {name: name, value: value, units: units}
  type t = array<value> // Currently array of length 3: [min, value, max]
  // The type of each row in the data supplied to Dygraph: [index, dataArray, statsArray]
  type row = array<t>
  type rawRow = array<array<Js.Nullable.t<float>>> // type used by Dygraph

  type md = {
    commit: string,
    runAt: Js.Date.t,
    units: units,
    description: string,
    trend: string,
    lines: list<(int, int)>,
    run_job_id: option<string>,
  }

  let single = (x: float): t => [nan, x, nan]

  let many = (xs: array<float>): t => {
    switch computeStats(xs) {
    | Some((min, max, avg)) => [min, avg, max]
    | None => [nan, nan, nan]
    }
  }

  let map = (xs: array<(string, float)>): t => {
    open Belt.Map.String
    let m = fromArray(xs)
    [getWithDefault(m, "min", nan), getWithDefault(m, "avg", nan), getWithDefault(m, "max", nan)]
  }

  let valueWithErrorBars = (~mid, ~low, ~high): t => [low, mid, high]

  let dummyValue = [nan, nan, nan]

  let toValue = (row: t): value => row[1]
}

@new @module("dygraphs")
external init: ('element, array<DataRow.row>, 'options) => graph = "default"

@send
external ready: (graph, unit => unit) => unit = "ready"

@send
external setAnnotations: (graph, array<{.."series": string, "x": 'floatOrDate}>) => unit =
  "setAnnotations"

@send
external destroy: graph => unit = "destroy"

@send
external updateOptions: (graph, 'options) => unit = "updateOptions"

@send
external getColors: (graph, unit) => array<string> = "getColors"

type global
@module("dygraphs")
external global: global = "default"

@send
external _synchronize: (global, array<graph>, 'options) => unit = "synchronize"

module Legend = {
  type t = {
    label: string,
    labelHTML: string,
    yHTML: string,
    dashHTML: string,
  }
  type dygraph = {rawData_: array<DataRow.rawRow>}
  type many = {
    xHTML: string,
    series: array<t>,
    x: int,
    dygraph: dygraph,
  }
  let format = (~xTicks=?, data: many): string => {
    let xLabel = switch xTicks {
    | Some(xTicks) => Belt.Map.Int.get(xTicks, data.x)
    | None => Some(data.xHTML)
    }
    // Starting index for the stats. (data.series contains legend entries for each line we show - data followed by stats)
    let statsIndex = Array.length(data.series) / 2
    switch xLabel {
    | Some(xLabel) =>
      let html = "<b>" ++ DataHelpers.trimCommit(xLabel) ++ "</b>"
      let row = (dashHTML, labelHTML, yHTML) => {
        "<div class='dygraph-legend-row'>" ++
        (dashHTML ++
        ("<div>" ++ labelHTML ++ "&ndash; </div>") ++
        ("<div>" ++ " <b>" ++ yHTML ++ "</b>" ++ "</div>" ++ "</div>"))
      }
      let legend = Array.mapi((idx, unit: t) => {
        // Add extra header for overall stats
        let extraHeader = switch idx == statsIndex {
        | true => "<b>Overall Stats</b>"
        | _ => ""
        }
        // We check if the data point was originally a multi-value data point,
        // by testing if min and max are not Js.null. DataRow.single sets these
        // to null, while they are set to non-null by DataRow.many
        let rawRow = data.dygraph.rawData_[data.x][idx + 1] // rawData_ also has x-index, so idx+1
        let (min, max) = switch Array.length(rawRow) {
        | 3 => (rawRow[0], rawRow[2])
        | _ => (Js.Nullable.null, Js.Nullable.null)
        }
        let multiValue = !(Js.Nullable.isNullable(min) || Js.Nullable.isNullable(max))
        let rawToFloat = x =>
          x->Js.Nullable.toOption->Belt.Option.getExn->Js.Float.toPrecisionWithPrecision(~digits=4)
        let extraHTML = switch multiValue {
        | true if idx < statsIndex =>
          row(unit.dashHTML, "min", min->rawToFloat) ++ row(unit.dashHTML, "max", max->rawToFloat)
        | _ => ""
        }
        extraHeader ++ row(unit.dashHTML, unit.labelHTML, unit.yHTML) ++ extraHTML
      }, data.series)
      let legend = Array.fold_left((a, b) => a ++ b, "", legend)
      `<div class="dygraph-legend-formatter">${html}${legend}</div>`
    | None => ""
    }
  }
}

let convertTicks = (ticks: Belt.Map.Int.t<string>) => {
  ticks
  ->Belt.Map.Int.mapWithKey((idx, label) => {"v": idx, "label": label})
  ->Belt.Map.Int.valuesToArray
}

// Dygraph needs null values, and cannot handle NaNs correctly
let convertNanToNull = (xs: DataRow.t) =>
  Belt.Array.map(xs, x => Js.Float.isNaN(x) ? Obj.magic(Js.null) : x)

let category20colors = [
  "#1f77b4",
  "#aec7e8",
  "#ff7f0e",
  "#ffbb78",
  "#2ca02c",
  "#98df8a",
  "#d62728",
  "#ff9896",
  "#9467bd",
  "#c5b0d5",
  "#8c564b",
  "#c49c94",
  "#e377c2",
  "#f7b6d2",
  "#7f7f7f",
  "#c7c7c7",
  "#bcbd22",
  "#dbdb8d",
  "#17becf",
  "#9edae5",
]

let defaultOptions = (
  ~legendFormatter=?,
  ~xTicks=?,
  ~yLabel=?,
  ~labels=?,
  ~onClick=?,
  ~data=[],
  ~colors=category20colors,
  (),
) => {
  let ticker = {
    xTicks->Belt.Option.map(convertTicks)->Belt.Option.map((x, ()) => x)->Js.Null.fromOption
  }
  let statsIndex = labels->Belt.Option.getExn->Array.length / 2 + 1
  let series =
    labels
    ->Belt.Option.getExn
    ->Belt.Array.sliceToEnd(statsIndex)
    ->Belt.Array.map(x => {
      %raw(`{[x]: {
        "color": "#888888",
        "strokeWidth": 1.0,
        "strokePattern": [3, 2],
        "highlightCircleSize": 0,
      }}`)
    })
  let series = series->Belt.Array.reduce(Js.Obj.empty(), (acc, s) => Js.Obj.assign(acc, s))
  {
    "file": data,
    "axes": {
      "x": {
        "drawGrid": true,
        "drawAxis": false,
        "ticker": ticker,
      },
      "y": {
        "drawAxis": true,
        "axisLabelWidth": 55,
      },
    },
    "series": series,
    "showRoller": false,
    "rollPeriod": 1,
    "xRangePad": 0,
    "includeZero": true,
    "highlightCircleSize": 4,
    "legendFormatter": Js.Null.fromOption(legendFormatter),
    "legend": "follow",
    "strokeWidth": 1.5,
    "customBars": true,
    "fillGraph": false,
    "pointClickCallback": Js.Null.fromOption(onClick),
    "colors": colors,
    // "animatedZooms": true,
    "digitsAfterDecimal": 3,
    "hideOverlayOnMouseOut": true,
    "labels": Js.Null.fromOption(labels),
    "ylabel": Js.Null.fromOption(yLabel),
  }
}

Sx.global(".dygraph-legend", [Sx.absolute, Sx.z.high])
Sx.global(
  ".dygraph-legend-formatter",
  [
    Sx.text.sm,
    Sx.bg.color(Sx.white),
    Sx.rounded.sm,
    Sx.py.md,
    Sx.px.xl,
    {
      open Css
      [
        boxShadows(list{
          Shadow.box(~blur=px(1), rgba(67, 90, 111, #num(0.3))),
          Shadow.box(~y=px(2), ~blur=px(4), ~spread=px(-2), rgba(67, 90, 111, #num(0.47))),
        }),
      ]
    },
  ],
)

Sx.global(
  ".dygraph-legend-line",
  [Sx.d.inlineBlock, Sx.relative, Sx.pl.lg, Sx.mr.lg, Sx.borderB.xl],
)

Sx.global(".dygraph-legend-row", [Sx.d.flex, Sx.items.center, Sx.mr.sm, Sx.flex.noWrap])

Sx.global(".dygraph-axis-label-y", [Sx.pr.sm])

Sx.global(".dygraph-axis-label", [Sx.text.xs, Sx.z.high, Sx.overflow.hidden, Sx.opacity75])

let graphSx = [Sx.unsafe("height", "150px")]

let containerSxBase = [Sx.w.full, Sx.rounded.md, Sx.p.lg]
let containerSxFailed = Belt.Array.concat(
  containerSxBase,
  [Sx.border.color(Sx.red300), Sx.border.xs, Sx.border.dashed],
)
let containerSx = Belt.Array.concat(containerSxBase, [Sx.border.color(Sx.gray300), Sx.border.xs])

let onPointClick = (xTicks, goToCommit, _e, point) => {
  let commit = switch xTicks {
  | Some(xTicks) => xTicks->Belt.Map.Int.get(point["idx"])
  | _ => None
  }
  switch (commit, goToCommit) {
  | (Some(commit), Some(goToCommit)) => goToCommit(commit)
  | _ => ()
  }
}

let computeConstantSeries = data => {
  let values = data->Belt.Array.map(DataRow.toValue)
  let mean = values->computeMean->Belt.Option.getWithDefault(0.0)
  let stdDev = computeStdDev(~mean, values)
  DataRow.valueWithErrorBars(~mid=mean, ~low=mean -. stdDev, ~high=mean +. stdDev)
}

let floatToStringHandleNaN = (~digits=4, x) => {
  Js.Float.isNaN(x) ? "?" : Js.Float.toPrecisionWithPrecision(~digits, x)
}

let makeDygraphData = (data: array<DataRow.row>, linesState) => {
  let data =
    data->Belt.Array.keepWithIndex((_, idx) =>
      linesState->Belt.Array.get(idx)->Belt.Option.getWithDefault(true)
    )
  let constantSeries = data->Belt.Array.map(computeConstantSeries)
  let nullConstantSeries = constantSeries->Belt.Array.map(convertNanToNull)

  let data =
    data
    // Dygraph does not display the last tick, so a dummy value
    // is added a the end of the data to overcome this.
    // See: https://github.com/danvk/dygraphs/issues/506
    ->Belt.Array.map(x => Belt.Array.concat(x, [DataRow.dummyValue]))
    ->Belt.Array.map(x => x->Belt.Array.map(convertNanToNull))

  let n = data->Belt.Array.get(0)->Belt.Option.getWithDefault([])->Belt.Array.length

  // Data passed onto Dygraph looks like array<[idx, value1, value2, ..., stats1, stats2, ...]>
  Belt.Array.range(0, n - 1)->Belt.Array.map(idx =>
    Belt.Array.concatMany([[Obj.magic(idx)], data->Belt.Array.map(d => d[idx]), nullConstantSeries])
  )
}

let makeDygraphLabels = (labels, linesState) =>
  labels
  ->Belt.Option.getWithDefault([])
  ->Belt.Array.keepWithIndex((_, idx) =>
    linesState->Belt.Array.get(idx)->Belt.Option.getWithDefault(true)
  )
  ->(
    labels => {
      let means =
        Belt.Array.length(labels) > 1 ? labels->Belt.Array.map(x => "mean:" ++ x) : ["mean"]
      Belt.Array.concatMany([["idx"], labels, means])
    }
  )

let graphColors = (labels, linesState, colorLabelMapping) => {
  let labels_ = labels->Belt.Option.getWithDefault([])
  let n = category20colors->Belt.Array.length
  let colorsArray =
    labels_->Belt.Array.mapWithIndex((idx, label) =>
      colorLabelMapping->Belt.Map.String.getWithDefault(
        label,
        category20colors->Belt.Array.getExn(mod(idx, n)),
      )
    )

  colorsArray->Belt.Array.keepWithIndex((_, idx) =>
    linesState->Belt.Array.get(idx)->Belt.Option.getWithDefault(true)
  )
}

let handleLegendClick = (label, labels, linesState, setLinesState, _e) => {
  let index = labels->Belt.Array.getIndexBy(l => l == label)->Belt.Option.getWithDefault(-1)
  setLinesState(_ =>
    linesState->Belt.Array.mapWithIndex((idx, state) => idx == index ? !state : state)
  )
}

module OverlayLegend = {
  @react.component
  let make = React.memo((~legendData, ~units, ~labels, ~linesState, ~setLinesState) => {
    <Row
      spacing=#between
      sx=[
        Sx.items.start,
        Sx.flex.wrap,
        Sx.unsafe("width", "min-content"),
        Sx.unsafe("display", "grid"),
        Sx.unsafe("gridTemplateColumns", "auto auto auto auto auto auto"),
        Sx.unsafe("gap", "8px"),
      ]>
      {legendData
      ->Belt.SortArray.stableSortBy(((_, (vA, _, _)), (_, (vB, _, _))) => compare(vB, vA))
      ->Belt.Array.mapWithIndex((idx, (label, (value, active, color))) => {
        let hex = color->Js.String2.substr(~from=1)
        <div
          key={idx->Belt.Int.toString}
          onClick={handleLegendClick(label, labels, linesState, setLinesState)}
          className={Sx.make([
            Sx.d.inlineFlex,
            Sx.items.center,
            Sx.flex.noWrap,
            Sx.unsafe("gap", "4px"),
            Sx.pointer,
          ])}>
          <span
            className={Sx.make([
              Sx.mr.zero,
              active ? Sx.opacity100 : Sx.opacity25,
              Sx.text.color(Css.hex(hex)),
            ]) ++ " dygraph-legend-line"}
          />
          <Text sx=[Sx.text.sm, Sx.text.color(Sx.gray900)]> {label ++ ":"} </Text>
          <Text sx=[Sx.text.sm, Sx.text.color(Sx.gray900)]> {value->floatToStringHandleNaN} </Text>
          <Text sx=[Sx.text.sm]> units </Text>
        </div>
      })
      ->Rx.array(~empty=<Message text="No labels" />)}
    </Row>
  })
}

type elementOrString =
  | String(string)
  | Element(React.element)

module GraphInfo = {
  @react.component
  let make = React.memo((~title, ~subTitle, ~run_job_id, ~lines) => {
    switch title {
    | Some(title) =>
      <Column spacing=Sx.lg sx=[Sx.w.auto]>
        <div className={Sx.make([Sx.d.flex, Sx.flex.row, Sx.items.baseline])}>
          <Text sx=[Sx.leadingNone, Sx.text.bold, Sx.text.md, Sx.mr.md]> title </Text>
          {switch subTitle {
          | String(text) =>
            <Text
              sx=[
                Sx.leadingNone,
                Sx.text.sm,
                Sx.text.color(Sx.gray600),
                [Css.minHeight(#em(1.0))],
                Sx.mr.md,
              ]>
              {text}
            </Text>
          | Element(elem) => elem
          }}
          {switch (run_job_id, lines->Belt.List.get(0)) {
          | (Some(jobId), Some(lines)) =>
            <a target="_blank" href={jobUrl(jobId, ~lines)}>
              {<Icon sx=[Sx.unsafe("width", "12px")] svg=Icon.help />}
            </a>
          | _ => Rx.null
          }}
        </div>
      </Column>
    | None => React.null
    }
  })
}

@react.component
let make = React.memo((
  ~sx as uSx=[],
  ~title=?,
  ~subTitle: elementOrString=String(""),
  ~xTicks: option<Belt.Map.Int.t<string>>=?,
  ~yLabel: option<string>=?,
  ~labels: option<array<string>>=?,
  ~goToCommit=?,
  ~annotations: array<{
    "clickHandler": (annotation, point, graph, event) => unit,
    "height": int,
    "icon": string,
    "series": string,
    "text": string,
    "width": int,
    "x": int,
  }>=[],
  ~dataSet: array<DataRow.row>,
  ~units: DataRow.units,
  ~lines: DataRow.lines,
  ~run_job_id: option<string>,
  ~failedMetric: bool,
  ~labelColorMapping: Belt.Map.String.t<string>,
) => {
  let graphDivRef = React.useRef(Js.Nullable.null)
  let graphRef = React.useRef(None)
  let (legendColors, setLegendColors) = React.useState(() => [])
  let (linesState, setLinesState) = React.useState(() => [])

  let intersection = Hooks.useIntersection(graphDivRef, IntersectionObserver.makeOption())

  let isIntersecting =
    intersection
    ->Belt.Option.map(IntersectionObserver.Entry.isIntersecting)
    ->Belt.Option.getWithDefault(false)

  React.useMemo1(() => {
    let state = switch labels {
    | Some(labels) => Belt.Array.make(Belt.Array.length(labels), true)
    | _ => []
    }
    setLinesState(_ => state)
  }, [labels])

  React.useEffect1(() => {
    let options = defaultOptions(
      ~yLabel?,
      ~labels=makeDygraphLabels(labels, linesState),
      ~colors=graphColors(labels, linesState, labelColorMapping),
      ~xTicks?,
      ~onClick=onPointClick(xTicks, goToCommit),
      ~legendFormatter=Legend.format(~xTicks?),
      (),
    )

    switch Js.Nullable.toOption(graphDivRef.current) {
    | None => ()
    | Some(ref) =>
      switch (graphRef.current, isIntersecting) {
      | (None, true) => {
          let graph = init(ref, makeDygraphData(dataSet, linesState), options)
          graphRef.current = Some(graph)
          setLegendColors(_ => graph->getColors())

          if Array.length(annotations) > 0 {
            graph->ready(() => {
              graph->setAnnotations(annotations)
            })
          }
        }
      | _ => ()
      }
    }
    Some(
      _ => {
        switch graphRef.current {
        | Some(graph) => {
            graph->destroy
            graphRef.current = None
          }
        | None => ()
        }
      },
    )
  }, [isIntersecting])

  React.useLayoutEffect3(() => {
    switch graphRef.current {
    | None => ()
    | Some(graph) => {
        let options = defaultOptions(
          ~yLabel?,
          ~colors=graphColors(labels, linesState, labelColorMapping),
          ~labels=makeDygraphLabels(labels, linesState),
          ~xTicks?,
          ~onClick=onPointClick(xTicks, goToCommit),
          ~data=makeDygraphData(dataSet, linesState),
          ~legendFormatter=Legend.format(~xTicks?),
          (),
        )
        graph->updateOptions(options)
        graph->setAnnotations(annotations)
      }
    }
    None
  }, (dataSet, annotations, linesState))

  let labels = labels->Belt.Option.getWithDefault([])
  let lastValues = dataSet->Belt.Array.map(x => x->BeltHelpers.Array.lastExn->DataRow.toValue)
  let zip3 = (xs, ys, zs) => Belt.Array.zip(xs, ys)->Belt.Array.zipBy(zs, ((x, y), z) => (x, y, z))
  let legendData = labels->Belt.Array.zip(zip3(lastValues, linesState, legendColors))
  let isOverlayed = labels->Belt.Array.length > 1

  let left = <GraphInfo title subTitle lines run_job_id />
  let right = isOverlayed
    ? <OverlayLegend legendData units labels linesState setLinesState />
    : <Row alignX=#right spacing=Sx.md sx=[Sx.w.auto]>
        <Text sx=[Sx.leadingNone, Sx.text.md, Sx.text.bold, Sx.text.color(Sx.gray900)]>
          {lastValues->BeltHelpers.Array.lastExn->floatToStringHandleNaN}
        </Text>
        <Text sx=[Sx.leadingNone, Sx.text.md, Sx.text.bold, Sx.text.color(Sx.gray500)]>
          units
        </Text>
      </Row>

  let sx = Array.append(uSx, failedMetric ? containerSxFailed : containerSx)

  <div className={Sx.make(sx)}>
    <Row spacing=#between alignY=#top sx={[Sx.mb.lg]}> {left} {right} </Row>
    <div className={Sx.make(graphSx)} ref={ReactDOM.Ref.domRef(graphDivRef)} />
  </div>
})
