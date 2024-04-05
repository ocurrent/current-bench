open Components

type options = {
  "element": Dom.element,
  "startDate": Js.Null.t<Js.Date.t>,
  "endDate": Js.Null.t<Js.Date.t>,
  "selectBackward": bool,
  "selectForward": bool,
  "singleMode": bool,
  "onSelect": Js.Null.t<(Js.Date.t, Js.Date.t) => unit>,
}

type t = {setDateRange: (Js.Date.t, Js.Date.t) => unit}

@new @module("litepicker")
external init: options => t = "default"

@module("./litepicker-bindings") external bindPickerMethods: t => unit = "bindPickerMethods"

let containerSx = [Sx.rounded.sm, Sx.border.xs, Sx.border.color(Sx.gray300)]

let elementSx = [Sx.border.none, Sx.text.semibold, Sx.text.sm, Sx.py.lg, Sx.px.xs, Sx.pointer]

let getDefaultDateRange = {
  let hourMs = 3600.0 *. 1000.
  let dayMs = hourMs *. 24.
  () => {
    let ts2 = Js.Date.now()
    let ts1 = ts2 -. 90. *. dayMs
    (Js.Date.fromFloat(ts1), Js.Date.fromFloat(ts2))
  }
}

@react.component
let make = (~sx as uSx=[], ~startDate=?, ~endDate=?, ~onSelect=?) => {
  let (showFullHistory, setShowFullHistory) = React.useState(() => false)

  let onSelect = switch onSelect {
  | None => None
  | Some(f) =>
    Some(
      (startDate, endDate) => {
        Js.Date.setHoursMS(endDate, ~hours=23.0, ~minutes=59.0, ~seconds=59.0, ())->ignore
        f(startDate, endDate)
      },
    )
  }
  let elementRef = React.useRef(Js.Nullable.null)
  let pickerRef = React.useRef(None)

  let setDateRange = (startDate, endDate) => {
    switch pickerRef.current {
    | None => ()
    | Some(picker) => picker.setDateRange(startDate, endDate)
    }
  }
  let changeDateRange = _ => {
    if showFullHistory {
      // currently showing full history
      let (startDate, endDate) = getDefaultDateRange()
      setDateRange(startDate, endDate)
    } else {
      // currently showing short history
      let startDate = Js.Date.makeWithYM(~year=2000.0, ~month=0., ())
      let endDate = Js.Date.makeWithYM(~year=2100.0, ~month=0., ())
      setDateRange(startDate, endDate)
    }
    setShowFullHistory(_ => !showFullHistory)
  }

  React.useEffect0(() => {
    let options = {
      "element": elementRef.current |> Js.Nullable.toOption |> Belt.Option.getExn,
      "startDate": startDate |> Js.Null.fromOption,
      "endDate": endDate |> Js.Null.fromOption,
      "selectBackward": false,
      "selectForward": false,
      "singleMode": false,
      "onSelect": onSelect |> Js.Null.fromOption,
    }
    let picker = init(options)
    pickerRef.current = Some(picker)
    bindPickerMethods(picker)
    None
  })

  let sx = Array.append(uSx, containerSx)
  <Row sx alignX=#center alignY=#center>
    <Icon svg=Icon.calendar />
    <input className={Sx.make(elementSx)} ref={ReactDOM.Ref.domRef(elementRef)} />
    <button
      title={showFullHistory ? "Show short history" : "Show full history"}
      onClick={changeDateRange}>
      <Icon
        sx=[Sx.unsafe("width", "24px"), Sx.unsafe("height", "24px")]
        svg={showFullHistory ? Icon.zoomIn : Icon.zoomOut}
      />
    </button>
  </Row>
}
