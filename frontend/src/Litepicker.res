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

type t

@new @module("litepicker")
external init: options => t = "default"

let containerSx = [Sx.rounded.sm, Sx.border.xs, Sx.border.color(Sx.gray300)]

let elementSx = [Sx.border.none, Sx.text.semibold, Sx.text.sm, Sx.py.lg, Sx.px.xs]

@react.component
let make = (~sx as uSx=[], ~startDate=?, ~endDate=?, ~onSelect=?) => {
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
    let _self = init(options)

    None
  })

  let sx = Array.append(uSx, containerSx)
  <Row sx alignX=#center alignY=#center>
    <Icon svg=Icon.calendar />
    <input className={Sx.make(elementSx)} ref={ReactDOMRe.Ref.domRef(elementRef)} />
  </Row>
}
