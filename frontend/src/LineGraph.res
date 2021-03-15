type graph
type annotation
type point
type event

@new @module("dygraphs")
external init: ('element, array<array<float>>, 'options) => graph = "default"

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
    | Some(xTicks) => Belt.Map.Int.get(xTicks, data.x)->Belt.Option.getWithDefault(data.xHTML)
    | None => data.xHTML
    }
    let html = "<b>" ++ (xLabel ++ "</b>")
    let legend = Array.map((unit: t) => {
      "<div class='dygraph-legend-row'>" ++
      (unit.dashHTML ++
      ("<div>" ++ (" <b>" ++ (unit.yHTML ++ ("</b>" ++ ("</div>" ++ "</div>"))))))
    }, data.series)
    let legend = Array.fold_left((a, b) => a ++ b, "", legend)
    html ++ legend
  }
}

let convertTicks = (ticks: Belt.Map.Int.t<string>) => {
  ticks
  ->Belt.Map.Int.mapWithKey((idx, label) => {"v": idx, "label": label})
  ->Belt.Map.Int.valuesToArray
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
        "drawGrid": false,
        "drawAxis": true,
        "axisLineColor": "gainsboro",
        "axisLineWidth": 1.5,
        "axisLabelFormatter": Js.Null.fromOption(xLabelFormatter),
        "ticker": ticker,
      },
      "y": {
        "drawAxis": true,
        "gridLineWidth": 1.5,
        "gridLineColor": "#eee",
        "gridLinePattern": [5, 5],
        "axisLineColor": "gainsboro",
        "axisLineWidth": 1.5,
        "axisLabelWidth": 50,
      },
    },
    "rollPeriod": 1,
    "xRangePad": 0,
    "drawAxesAtZero": true,
    "highlightCircleSize": 5,
    "legendFormatter": Js.Null.fromOption(legendFormatter),
    "legend": "follow",
    "showRoller": false,
    "strokeWidth": 2,
    "fillGraph": true,
    "pointClickCallback": Js.Null.fromOption(onClick),
    "colors": ["#0F6FDE"],
    "animatedZooms": true,
    "hideOverlayOnMouseOut": true,
    "labels": Js.Null.fromOption(labels),
    "ylabel": Js.Null.fromOption(yLabel),
  }
}

Sx.global(
  ".dygraph-legend",
  [
    Sx.absolute,
    Sx.text.sm,
    Sx.z.high,
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

let graphSx = [Sx.absolute, Sx.t.xl3, Sx.b.zero, Sx.l.zero, Sx.r.zero]

let containerSx = [Sx.mt.xl2, Sx.relative, Sx.unsafe("width", "480px"), Sx.h.xl5]

@react.component
let make = React.memo((
  ~sx as uSx=[],
  ~title=?,
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

  // Dygraph does not display the last tick, so a dummy value
  // is added a the end of the data to overcome this.
  // See: https://github.com/danvk/dygraphs/issues/506
  let lastRow = data->BeltHelpers.Array.last
  let data = switch lastRow {
  | Some(lastRow) => BeltHelpers.Array.push(data, [lastRow[0] +. 1.0, Obj.magic(Js.Nullable.null)])
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

  let title = switch title {
  | Some(title) => <h3 className={Sx.make([Sx.text.center])}> {React.string(title)} </h3>
  | None => React.null
  }

  let sx = Array.append(uSx, containerSx)

  <div className={Sx.make(sx)}>
    title <div className={Sx.make(graphSx)} ref={ReactDOMRe.Ref.domRef(graphDivRef)} />
  </div>
})
