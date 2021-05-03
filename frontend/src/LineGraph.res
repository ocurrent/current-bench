type graph
type annotation
type point
type event

let computeStdDev = (~mean, xs) => {
  let var = ref(0.0)
  let n = Array.length(xs)
  for i in 0 to n - 1 {
    let x = xs[i] -. mean
    var := var.contents +. x *. x
  }
  sqrt(var.contents /. float_of_int(n - 1))
}

let computeMean = xs => {
  if Array.length(xs) == 0 {
    None
  } else {
    let (total, count) = Array.fold_left(((total, count), x) => {
      if Js.Float.isNaN(x) {
        (total, count +. 1.)
      } else {
        let total = total +. x
        let count = count +. 1.
        (total, count)
      }
    }, (0., 0.), xs)
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
  type value
  type t = array<value>

  let single = (x: float): value =>
    Obj.magic([Obj.magic(Js.null), Obj.magic(x), Obj.magic(Js.null)])

  let many = (xs: array<float>): value => {
    switch computeStats(xs) {
    | Some((min, max, avg)) => Obj.magic([min, avg, max])
    | None => Obj.magic([Obj.magic(Js.null), nan, Obj.magic(Js.null)])
    }
  }

  let valueWithErrorBars = (~mid, ~low, ~high): value => {
    Obj.magic([Obj.magic(low), Obj.magic(mid), Obj.magic(high)])
  }

  let with_index = (index: int, value): t => [Obj.magic(index), value]
  let with_date = (date: Js.Date.t, value): t => [Obj.magic(date), value]

  let set_index = (index: int, row: t): unit => {
    let index: value = Obj.magic(index)
    Belt.Array.set(row, 0, index)->ignore
  }

  let unsafe_get_index = (row): int => {
    Obj.magic(row[0])
  }

  let nan = (~index): t => [
    Obj.magic(index),
    Obj.magic([Obj.magic(Js.null), nan, Obj.magic(Js.null)]),
  ]

  // Similar to nan, but with for two series.
  let nan2 = (~index): t => [
    Obj.magic(index),
    Obj.magic([Obj.magic(Js.null), nan, Obj.magic(Js.null)]),
    Obj.magic([Obj.magic(Js.null), nan, Obj.magic(Js.null)]),
  ]

  let toFloat = (row: t): float => {
    let value = row[1]
    if Js.Array.isArray(value) {
      let values: array<float> = Obj.magic(value)
      values[1]
    } else {
      let value: float = Obj.magic(value)
      value
    }
  }

  let add_value = (row: t, value: value): t => {
    Js.Array.push(value, row)->ignore
    row
  }
}

@new @module("dygraphs")
external init: ('element, array<DataRow.t>, 'options) => graph = "default"

@send
external ready: (graph, unit => unit) => unit = "ready"

@send
external setAnnotations: (graph, array<{.."series": string, "x": 'floatOrDate}>) => unit =
  "setAnnotations"

@send
external destroy: graph => unit = "destroy"

@send
external updateOptions: (graph, 'options) => unit = "updateOptions"

type global
@module("dygraphs")
external global: global = "default"

@send
external _synchronize: (global, array<graph>, 'options) => unit = "synchronize"

let getElementsByClassName: string => array<Dom.element> = %raw(`
  function(className) {
    return document.getElementsByClassName(className)
  }
`)

let getElementHTMLonClick: (Dom.element, string => unit) => unit = %raw(`
  function(elem, handler) {
    elem.onclick = function(e) { handler(e.target.innerHTML) }
  }
`)

module Legend = {
  type t = {
    labelHTML: string,
    yHTML: string,
    dashHTML: string,
  }
  type many = {
    xHTML: string,
    series: array<t>,
    x: int,
  }
  let format = (~xTicks=?, data: many): string => {
    let xLabel = switch xTicks {
    | Some(xTicks) => Belt.Map.Int.get(xTicks, data.x)
    | None => Some(data.xHTML)
    }
    switch xLabel {
    | Some(xLabel) =>
      let html = "<b>" ++ (xLabel ++ "</b>")
      let legend = Array.map((unit: t) => {
        "<div class='dygraph-legend-row'>" ++
        (unit.dashHTML ++
        ("<div>" ++ (" <b>" ++ (unit.yHTML ++ ("</b>" ++ ("</div>" ++ "</div>"))))))
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

let addSeries = (data: array<DataRow.t>, series: array<DataRow.value>) => {
  assert (Array.length(data) == Array.length(series))
  data->Belt.Array.mapWithIndex((i, row) => DataRow.add_value(row, series[i]))
}

let defaultOptions = (
  ~legendFormatter=?,
  ~xTicks=?,
  ~yLabel=?,
  ~labels=?,
  ~onClick=?,
  ~data=[],
  ~xLabelFormatter=?,
  (),
) => {
  let ticker = {
    xTicks->Belt.Option.map(convertTicks)->Belt.Option.map((x, ()) => x)->Js.Null.fromOption
  }
  {
    "file": data,
    "axes": {
      "x": {
        "drawGrid": true,
        "drawAxis": true,
        "axisLabelFormatter": Js.Null.fromOption(xLabelFormatter),
        "ticker": ticker,
        "axisLabelWidth": 45,
      },
      "y": {
        "drawAxis": true,
        "axisLabelWidth": 55,
      },
    },
    "series": {
      "std-dev": {
        "strokeWidth": 1.0,
        "strokePattern": [3, 2],
        "highlightCircleSize": 0,
      },
    },
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
    "colors": ["#0F6FDE", "#888888"],
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

let graphSx = [Sx.unsafe("height", "190px"), Sx.unsafe("marginBottom", "40px")]

let containerSx = [Sx.w.full, Sx.border.xs, Sx.border.color(Sx.gray300), Sx.rounded.md, Sx.p.xl]

open Components

@react.component
let make = React.memo((
  ~sx as uSx=[],
  ~title=?,
  ~subTitle=?,
  ~xTicks: option<Belt.Map.Int.t<string>>=?,
  ~yLabel: option<string>=?,
  ~labels: option<array<string>>=?,
  ~onXLabelClick=?,
  ~annotations: array<{
    "clickHandler": (annotation, point, graph, event) => unit,
    "height": int,
    "icon": string,
    "series": string,
    "text": string,
    "width": int,
    "x": int,
  }>=[],
  ~data,
) => {
  let graphDivRef = React.useRef(Js.Nullable.null)
  let graphRef = React.useRef(None)

  // Add constant stdDev series.
  let constantSeries = {
    let values = data->Belt.Array.map(DataRow.toFloat)
    let mean = values->computeMean->Belt.Option.getWithDefault(0.0)
    let stdDev = computeStdDev(~mean, values)
    Array.make(
      Array.length(data),
      DataRow.valueWithErrorBars(~mid=mean, ~low=mean -. stdDev, ~high=mean +. stdDev),
    )
  }
  let data = addSeries(data, constantSeries)
  let labels = labels->Belt.Option.map(labels => {
    Js.Array.push("std-dev", labels)->ignore
    labels
  })

  // Dygraph does not display the last tick, so a dummy value
  // is added a the end of the data to overcome this.
  // See: https://github.com/danvk/dygraphs/issues/506
  let lastRow = data->BeltHelpers.Array.last
  let data = switch lastRow {
  | Some(lastRow) =>
    let lastIndex = DataRow.unsafe_get_index(lastRow)
    BeltHelpers.Array.push(data, DataRow.nan2(~index=lastIndex + 1))
  | None => data
  }

  React.useEffect1(() => {
    let options = defaultOptions(
      ~yLabel?,
      ~labels?,
      ~xTicks?,
      ~legendFormatter=Legend.format(~xTicks?),
      (),
    )

    switch Js.Nullable.toOption(graphDivRef.current) {
    | None => ()
    | Some(ref) => {
        let graph = init(ref, data, options)
        graphRef.current = Some(graph)

        if Array.length(annotations) > 0 {
          graph->ready(() => {
            graph->setAnnotations(annotations)
          })
        }

        switch onXLabelClick {
        | Some(handler) =>
          getElementsByClassName("dygraph-axis-label-x")->Belt.Array.forEach(elem =>
            getElementHTMLonClick(elem, handler)
          )
        | None => ()
        }
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
  }, [])

  React.useLayoutEffect2(() => {
    switch graphRef.current {
    | None => ()
    | Some(graph) => {
        let options = defaultOptions(
          ~yLabel?,
          ~labels?,
          ~xTicks?,
          ~data,
          ~legendFormatter=Legend.format(~xTicks?),
          (),
        )
        graph->updateOptions(options)
        graph->setAnnotations(annotations)

        switch onXLabelClick {
        | Some(handler) =>
          getElementsByClassName("dygraph-axis-label-x")->Belt.Array.forEach(elem =>
            getElementHTMLonClick(elem, handler)
          )
        | None => ()
        }
      }
    }
    None
  }, (data, annotations))

  let lastValue = data
  // take into account the dummy value added at the end of the data (to show the last tick)
  ->Belt.Array.get(Belt.Array.length(data) - 2)

  let left = switch title {
  | Some(title) =>
    <Column spacing=Sx.lg sx=[Sx.w.auto]>
      <Text sx=[Sx.leadingNone, Sx.text.bold, Sx.text.xl]> title </Text>
      {Rx.onSome(subTitle, subTitle =>
        <Text sx=[Sx.leadingNone, Sx.text.sm, Sx.text.color(Sx.gray600)]> subTitle </Text>
      )}
    </Column>
  | None => React.null
  }

  let right =
    <Row alignX=#right spacing=Sx.md sx=[Sx.w.auto]>
      <Text sx=[Sx.leadingNone, Sx.text.xl2, Sx.text.bold, Sx.text.color(Sx.gray900)]>
        {lastValue->Belt.Option.mapWithDefault("", value =>
          Js.Float.toPrecisionWithPrecision(~digits=4, DataRow.toFloat(value))
        )}
      </Text>
      <Text sx=[Sx.leadingNone, Sx.text.xl2, Sx.text.bold, Sx.text.color(Sx.gray500)]> {""} </Text> // TODO: unit needs to be added to the metrics
    </Row>

  let sx = Array.append(uSx, containerSx)

  <div className={Sx.make(sx)}>
    <Row spacing=#between alignY=#top sx={[Sx.mb.xl]}> {left} {right} </Row>
    <div className={Sx.make(graphSx)} ref={ReactDOM.Ref.domRef(graphDivRef)} />
  </div>
})
