module Option = {
  type t<'a> = option<'a>

  let map = (f, self) =>
    switch self {
    | Some(x) => Some(f(x))
    | None => None
    }

  let if_some = (f, self) =>
    switch self {
    | Some(x) => f(x)
    | _ => ()
    }

  let if_none = (f, self) =>
    switch self {
    | None => f()
    | _ => ()
    }

  let or = (self, default) =>
    switch self {
    | Some(x) => x
    | None => default
    }
}

let or = Option.or

let identity = x => x

type align = [#left | #center | #right]

let alignX_rule = alignX =>
  switch alignX {
  | #left => Sx.items.start
  | #right => Sx.items.end
  | #center => Sx.items.center
  }

let alignY_rule = alignY =>
  switch alignY {
  | #top => Sx.justify.start
  | #bottom => Sx.justify.end
  | #center => Sx.justify.center
  }

/*
   A pure ReasonML component library built on top of Sx.
   Sx is a low-level "utility" styling library (See Sx.re).

   Main sources of inspiration:

   - https://radix.modulz.app/docs/getting-started/
   - https://styled-system.com
   - https://primer.style/components/
   - https://priceline.github.io
   - https://getbootstrap.com/docs/4.5/getting-started/introduction/


 */

module Column = {
  type spacing = [#between | #around | #even | Css.Types.Length.t]

  let spacing_rule = (spacing: spacing) =>
    switch spacing {
    | #between => Sx.justify.between
    | #around => Sx.justify.around
    | #even => Sx.justify.evenly
    | len =>
      let len: Css.Types.Length.t = Obj.magic(len)
      Sx.selector("> * + *", [[Css.marginTop(len)]])
    }

  @react.component
  let make = (
    ~alignX=#left,
    ~alignY=#top,
    ~reverse=false,
    ~stretch=false,
    ~sx as uSx=[],
    ~spacing=?,
    ~children,
  ) => {
    let sx = Array.append(
      [
        Sx.boxBorder,
        Sx.d.flex,
        reverse ? Sx.flex.colRev : Sx.flex.col,
        Sx.flex.noWrap,
        alignX_rule(alignX),
        alignY_rule(alignY),
        Sx.with_some(spacing_rule, spacing),
        Sx.w.full,
        Sx.h.auto,
        Sx.on(stretch, Sx.items.stretch),
      ],
      uSx,
    )
    <div className={Sx.make(sx)}> children </div>
  }
}

module Row = {
  type align = [#left | #center | #right]

  let alignX_rule = alignX =>
    switch alignX {
    | #left => Sx.justify.start
    | #right => Sx.justify.end
    | #center => Sx.justify.center
    }

  let alignY_rule = alignY =>
    switch alignY {
    | #top => Sx.items.start
    | #bottom => Sx.items.end
    | #center => Sx.items.center
    }

  type spacing = [#none | #between | #around | #even | #px(int)]

  let spacing_rule = (spacing: spacing) =>
    switch spacing {
    | #none => Sx.empty
    | #between => Sx.justify.between
    | #around => Sx.justify.around
    | #even => Sx.justify.evenly
    | #px(n) => Sx.selector("> * + *", [[Css.marginLeft(#px(n))]])
    }

  @react.component
  let make = (
    ~alignX=#left,
    ~alignY=#top,
    ~reverse=false,
    ~stretch=false,
    ~sx as uSx=[],
    ~spacing=#none,
    ~children,
  ) => {
    let sx = [
      Sx.boxBorder,
      Sx.d.inlineFlex,
      reverse ? Sx.flex.rowRev : Sx.flex.row,
      Sx.flex.noWrap,
      alignX_rule(alignX),
      alignY_rule(alignY),
      spacing_rule(spacing),
      Sx.w.full,
      Sx.h.auto,
      Sx.on(stretch, Sx.items.stretch),
    ]
    <div className={Sx.make(Array.append(sx, uSx))}> children </div>
  }
}

module Flex = {
  let sx = [Sx.boxBorder, Sx.d.flex]

  let wrap_rule = (~wrap, ~reverse) =>
    switch (wrap, reverse) {
    | (false, _) => Sx.flex.noWrap
    | (true, false) => Sx.flex.wrap
    | (true, true) => Sx.flex.wrapRev
    }

  @react.component
  let make = (
    ~alignX=#left,
    ~alignY=#top,
    ~sx as uSx=[],
    ~txt=?,
    ~wrap=false,
    ~reverse=false,
    ~icon=?,
    ~children=?,
  ) => {
    let sx = Array.append(
      sx,
      [alignX_rule(alignX), alignY_rule(alignY), wrap_rule(~wrap, ~reverse)],
    )
    let sx = Array.append(sx, uSx)
    let txt = Rx.opt(txt |> Option.map(Rx.string))
    let icon = Rx.opt(icon)
    let children = Rx.opt(children)
    <div className={Sx.make(sx)}> icon txt children </div>
  }
}

module Block = {
  let sx = [Sx.w.full, Sx.boxBorder, Sx.d.block]

  @react.component
  let make = (~sx as uSx=[], ~txt=?, ~icon=?, ~children=?) => {
    let sx = Array.append(sx, uSx)

    let txt = Rx.opt(txt |> Option.map(Rx.string))
    let icon = Rx.opt(icon)
    let children = Rx.opt(children)
    <div className={Sx.make(sx)}> icon txt children </div>
  }
}

module Label = {
  let sx = {
    open Sx
    [d.flex, flex.col, items.start, w.full, text.color(gray900), text.sm]
  }

  @react.component
  let make = (~htmlFor=?, ~sx as uSx=[], ~text, ~children=?) => {
    let sx = Array.append(sx, uSx)

    <label className={Sx.make(sx)} ?htmlFor>
      <div className={Sx.make([Sx.text.bold, Sx.text.upper, Sx.text.sm])}>
        {React.string(text)}
      </div>
      {Rx.maybe(children, identity)}
    </label>
  }
}

module Button = {
  let sx_base = fill => {
    open Sx
    [
      pointer,
      d.block,
      bg.color(fill ? primary : white),
      on(fill, text.color(white)),
      rounded.md,
      text.bold,
      hover([bg.color(primary), text.color(white)]),
      active([bg.color(black), border.color(black), text.color(white)]),
    ]
  }

  let sx_small = {
    open Sx
    [text.sm, py.md, px.lg]
  }

  let sx_medium = {
    open Sx
    [py.lg, px.xl]
  }

  let sx_border = {
    open Sx
    [border.xs, border.color(primary)]
  }

  let sx_icon = {
    open Sx
    [
      border.none,
      d.flex,
      flex.row,
      items.center,
      Sx.selector("svg", [Sx.mr.md]),
      active([bg.color(black), border.color(black), text.color(white)]),
    ]
  }

  let sx_icon_hover = {
    open Sx
    [hover([bg.color(gray300)])]
  }

  let sx_minimal = {
    open Sx
    [bg.none, border.none, pointer, active([text.color(primary)])]
  }

  let sx_size = v =>
    switch v {
    | #small => sx_small
    | #medium => sx_medium
    }

  @react.component
  let make = (
    ~text=?,
    ~sx as uSx=[],
    ~minimal=false,
    ~size=#medium,
    ~fill=false,
    ~icon=?,
    ~onClick=?,
    ~name=?,
  ) => {
    let sx_border = if text == None {
      []
    } else {
      sx_border
    }
    let (text, sx_icon_hover, sx_size) = switch text {
    | Some(text) => (<span> {React.string(text)} </span>, [], sx_size(size))
    | None => (React.null, sx_icon_hover, [])
    }
    let (sx_icon, icon_svg) = switch icon {
    | Some(svg) => (sx_icon, svg)
    | None => ([], React.null)
    }
    let sx = minimal
      ? sx_minimal
      : Array.concat(list{sx_base(fill), sx_size, sx_icon, sx_icon_hover, sx_border})
    let sx = Array.append(sx, uSx)
    <button type_="button" className={Sx.make(sx)} ?onClick ?name> icon_svg text </button>
  }
}

module Field = {
  @react.component
  let make = (~label, ~sx as uSx=[], ~children) => <Label sx=uSx text=label> children </Label>
}

module Input = {
  let sx = {
    open Sx
    [
      [Css.lineHeight(#inherit_)],
      text.md,
      d.block,
      w.full,
      rounded.md,
      boxBorder,
      py.md,
      px.lg,
      border.xs,
      border.solid,
      border.color(gray400),
      appearanceNone,
      focus([border.color(primary), outlineNone]),
      placeholder([text.color(gray500)]),
    ]
  }

  type kind = [#text | #password]
  let kindToString = x =>
    switch x {
    | #text => "text"
    | #number => "number"
    | #password => "password"
    }

  @react.component
  let make = (
    ~kind=#text,
    ~sx as uSx=[],
    ~minimal=false,
    ~name=?,
    ~value=?,
    ~onChange=?,
    ~defaultValue=?,
    ~placeholder=?,
  ) => {
    let type_ = kindToString(kind)
    <input
      className={Sx.make(Array.append(minimal ? [] : sx, uSx))}
      type_
      ?defaultValue
      ?placeholder
      ?value
      ?onChange
      ?name
    />
  }

  module Number = {
    let containerSx = {
      open Sx
      [d.flex, flex.row, flex.noWrap, boxBorder, w.full, relative]
    }

    let buttonSx = {
      open Sx
      [
        text.mono,
        border.none,
        rounded.none,
        py.md,
        px.lg,
        bg.none,
        pointer,
        text.bold,
        text.md,
        text.color(gray300),
        hover([text.color(gray500)]),
        active([text.color(primary)]),
        bg.color(white),
      ]
    }

    @react.component
    let make = (~sx as uSx=[], ~name=?, ~value=?, ~onChange=?, ~defaultValue=?, ~placeholder=?) => {
      let (value, setValue) = React.useState(() => value)
      let incr = _ => setValue(_ => Option.map(x => x + 1, value))
      let decr = _ => setValue(_ => Option.map(x => x - 1, value))
      let onChange = e => {
        let value = ReactEvent.Form.target(e)["value"]
        switch int_of_string(value) {
        | exception _ => setValue(_ => value == "" || (value == "-" || value == "+") ? value : None)
        | value => setValue(_ => Some(value))
        }
        Option.if_some(f => f(value), onChange)
      }
      <div className={Sx.make(Array.append(containerSx, uSx))}>
        <input
          className={Sx.make(Array.append(sx, [Sx.minW.zero]))}
          ?defaultValue
          ?placeholder
          value={or(Option.map(string_of_int, value), "")}
          onChange
          ?name
        />
        <div
          className={Sx.make({
            open Sx
            [absolute, text.color(gray300), r.zero, self.center, mr.sm, bg.color(white), z.high]
          })}>
          <button onClick=decr className={Sx.make(buttonSx)}> {Rx.string("-")} </button>
          <button onClick=incr className={Sx.make(buttonSx)}> {Rx.string("+")} </button>
        </div>
      </div>
    }
  }
}

module Select = {
  let sx_select = {
    open Sx
    [
      appearanceNone,
      border.none,
      text.md,
      w.full,
      h.full,
      py.md,
      px.lg,
      [Css.lineHeight(#inherit_)],
      bg.color(transparent),
      boxBorder,
      focus([outlineNone, border.none]),
      active([outlineNone, border.none]),
      selector("-moz-focus-inner", [outlineNone, border.none]),
      Sx.invalid([Sx.text.color(Sx.gray600)]),
    ]
  }

  let sx = {
    open Sx
    [
      boxBorder,
      w.full,
      border.xs,
      border.color(Sx.gray400),
      pointer,
      rounded.md,
      d.flex,
      relative,
      active([border.color(primary), text.color(primary)]),
      text.color(gray300),
    ]
  }

  let sx_minimal = {
    open Sx
    [
      d.inlineBlock,
      pointer,
      active([border.color(primary), text.color(primary)]),
      text.color(gray300),
      p.zero,
    ]
  }

  @react.component
  let make = (
    ~name=?,
    ~sx as uSx=[],
    ~minimal=false,
    ~disabled=?,
    ~id=?,
    ~defaultValue=?,
    ~onChange=?,
    ~placeholder=?,
    ~value=?,
    ~children,
  ) =>
    <div className={Sx.make(Array.append(minimal ? sx_minimal : sx, uSx))}>
      <select
        required={placeholder != None}
        ?disabled
        ?id
        ?defaultValue
        ?onChange
        ?value
        ?name
        className={Sx.make(sx_select)}>
        {switch placeholder {
        | Some(placeholder) => <option value="" disabled=true> {React.string(placeholder)} </option>
        | None => React.null
        }}
        children
      </select>
      {Rx.on(
        !minimal,
        <svg
          className={Sx.make({
            open Sx
            [pointerEventsNone, absolute, r.zero, self.center, mr.sm, z.high]
          })}
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="currentcolor"
          ariaHidden=true>
          <path d="M7 10l5 5 5-5z" />
        </svg>,
      )}
    </div>
}

module InputX = {
  @react.component
  let make = (
    ~kind=?,
    ~sx=?,
    ~name=?,
    ~value=?,
    ~encode,
    ~decode,
    ~onChange=?,
    ~defaultValue=?,
    ~placeholder=?,
  ) => {
    let onChange = e => {
      let value = ReactEvent.Form.target(e)["value"]
      let value = decode(value)
      Option.if_some(f => f(value), onChange)
    }
    let value = Option.map(encode, value)
    let defaultValue = Option.map(encode, defaultValue)
    <Input ?defaultValue ?name ?kind ?sx ?placeholder ?value onChange />
  }
}

module SelectX = {
  @react.component
  let make = (
    ~name=?,
    ~sx=?,
    ~disabled=?,
    ~id=?,
    ~onChange=?,
    ~placeholder=?,
    ~encode,
    ~decode,
    ~options=[],
    ~value=?,
  ) => {
    let onChange = e => {
      let value = ReactEvent.Form.target(e)["value"]
      let value = decode(value)
      Option.if_some(f => f(value), onChange)
    }
    let value = Option.map(encode, value)
    <Select ?name ?sx ?disabled ?id ?placeholder ?value onChange>
      {options
      |> Array.mapi((i, opt) => <option key={string_of_int(i)}> {Rx.string(encode(opt))} </option>)
      |> (el => Rx.array(el))}
    </Select>
  }
}

module Checkbox = {
  let svgSx = [Sx.d.block]

  let sx = {
    open Sx
    [
      boxBorder,
      d.none,
      checked([
        selector(" ~ .sx-checkbox-unchecked", [d.none]),
        selector(" ~ .sx-checkbox-checked", [d.block]),
      ]),
      // // Uncheked
      selector(" ~ .sx-checkbox-unchecked", [d.block]),
      selector(" ~ .sx-checkbox-checked", [d.none]),
    ]
  }

  @react.component
  let make = (
    ~name=?,
    ~color=Sx.primary,
    ~sx as uSx=[],
    ~onChange=?,
    ~defaultChecked=?,
    ~checked=?,
  ) =>
    <div className={Sx.make(uSx)}>
      <input ?name ?onChange className={Sx.make(sx)} type_="checkbox" ?defaultChecked ?checked />
      <svg
        className={Sx.make(svgSx) ++ " sx-checkbox-unchecked"}
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill={Sx.gray400 |> Css.Types.Color.toString}
        ariaHidden=true>
        <path
          d="M19 5v14H5V5h14m0-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"
        />
      </svg>
      <svg
        className="sx-checkbox-checked"
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill={color |> Css.Types.Color.toString}
        ariaHidden=true>
        <path
          d="M19 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.11 0 2-.9 2-2V5c0-1.1-.89-2-2-2zm-9 14l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"
        />
      </svg>
    </div>
}

module Switch = {
  let containerSx = {
    open Sx
    [d.inlineBlock, mr.sm, [Css.minWidth(#px(40))]]
  }

  let labelSx = {
    open Sx
    [
      d.block,
      relative,
      pointer,
      bg.color(black),
      before([
        absolute,
        d.inlineBlock,
        Sx.unsafe("content", ""),
        [
          Css.height(#px(18)),
          Css.width(#px(18)),
          Css.borderRadius(#percent(100.0)),
          Css.top(#px(3)),
          Css.left(#px(3)),
          Css.unsafe("transition", "left .2s ease"),
          Css.unsafe("willChange", "left"),
        ],
        bg.color(white),
      ]),
      [Css.height(#px(24)), Css.borderRadius(#px(100))],
    ]
  }

  let inputSx = {
    open Sx
    [
      d.none,
      checked([
        selector(" ~ span", [bg.color(primary)]),
        selector(" ~ span:before", [[Css.left(#px(19))]]),
      ]),
    ]
  }

  @react.component
  let make = (~name=?, ~onToggle=?, ~on as checked=?) => {
    let onChange = switch onToggle {
    | Some(f) => Some(_ => f())
    | None => None
    }

    let sw = <input className={Sx.make(inputSx)} type_="checkbox" ?name ?checked ?onChange />

    <label className={Sx.make(containerSx)}> sw <span className={Sx.make(labelSx)} /> </label>
  }
}

module Message = {
  let sx = {
    open Sx
    [
      p.lg,
      borderL.md,
      borderL.color(primary),
      borderR.md,
      borderR.color(transparent),
      rounded.md,
      bg.color(highlight),
    ]
  }

  @react.component
  let make = (~sx as uSx=[], ~text) =>
    <Block sx={Array.append(sx, uSx)}> {React.string(text)} </Block>
}

module Textarea = {
  let sx = {
    open Sx
    [
      box,
      text.md,
      outlineNone,
      border.xs,
      border.color(gray400),
      rounded.md,
      bg.transparent,
      p.lg,
      appearanceNone,
      focus([border.color(primary), outlineNone]),
    ]
  }

  @react.component
  let make = (~name=?, ~sx as uSx=[], ~value=?, ~onChange=?, ~placeholder=?, ~rows=3) =>
    <textarea className={Sx.make(Array.append(sx, uSx))} ?value ?placeholder ?onChange ?name rows />
}

module Radio = {
  let baseSx = {
    open Sx
    [mr.xs, rounded.full, d.none]
  }

  let uncheckedStyle = {
    open Sx
    make(Array.append(baseSx, [text.color(gray400)]))
  }

  let checkedStyle = {
    open Sx
    make(Array.append(baseSx, [text.color(primary)]))
  }

  let inputStyle = {
    open Sx
    make([
      d.none,
      // Checked
      checked([
        selector(" ~ ." ++ uncheckedStyle, [d.none]),
        selector(" ~ ." ++ checkedStyle, [d.block]),
      ]),
      // // Uncheked
      selector(" ~ ." ++ uncheckedStyle, [d.block]),
      selector(" ~ ." ++ checkedStyle, [d.none]),
    ])
  }

  let sx = {
    open Sx
    [d.flex, items.center, pointer, text.bold]
  }

  @react.component
  let make = (~label=?, ~name=?, ~checked=?, ~onChange=?) => {
    let radio =
      <>
        <input ?name className=inputStyle type_="radio" ?checked ?onChange />
        <svg
          className=uncheckedStyle
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="currentcolor"
          ariaHidden=true>
          <path
            d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z"
          />
        </svg>
        <svg
          className=checkedStyle
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="currentcolor"
          ariaHidden=true>
          <path
            d="M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zm0-5C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z"
          />
        </svg>
      </>
    switch label {
    | Some(label) => <label className={Sx.make(sx)}> radio {React.string(label)} </label>
    | None => <Block> radio </Block>
    }
  }
}

module BlockRadio = {
  let baseSx = {
    open Sx
    list{mr.xs, rounded.full, d.none}
  }

  let contentClass = {
    open Sx
    [
      boxBorder,
      w.full,
      d.flex,
      flex.col,
      items.center,
      justify.center,
      pt.xl,
      pb.lg,
      bg.color(transparent),
      border.sm,
      border.color(gray400),
      rounded.full,
      bg.color(gray100),
      text.bold,
      selector("> :first-child", [mb.lg]),
    ] |> Sx.make
  }

  let contentCheckedSx = {
    open Sx
    [border.color(primary), bg.color(highlight)]
  }

  let inputSx = {
    open Sx
    [d.none, checked([selector(" ~ ." ++ contentClass, contentCheckedSx)])]
  }

  let labelSx = {
    open Sx
    [pointer, w.full, relative]
  }

  @react.component
  let make = (~label, ~icon=?, ~name=?, ~checked=?, ~onChange=?) =>
    <label className={Sx.make(labelSx)}>
      <input ?name className={Sx.make(inputSx)} type_="radio" ?checked ?onChange />
      <div className=contentClass> {or(icon, Rx.null)} {React.string(label)} </div>
    </label>
}

module Slider = {
  open Css

  let thumb = list{
    unsafe("appearance", "none"),
    unsafe("WebkitAppearance", "none"),
    unsafe("MozAppearance", "none"),
    backgroundColor(#currentColor),
    width(#px(18)),
    height(#px(18)),
    borderStyle(#none),
    borderRadius(#px(999)),
  }

  let css = style(list{
    width(#percent(100.0)),
    marginTop(Sx.md),
    marginBottom(Sx.md),
    height(#px(4)),
    cursor(#pointer),
    color(Sx.gray700),
    borderRadius(px(999)),
    background(Sx.gray400),
    unsafe("appearance", "none"),
    unsafe("WebkitAppearance", "none"),
    unsafe("MozAppearance", "none"),
    focus(list{color(Sx.primary), outline(zero, #none, transparent)}),
    active(list{color(Sx.primary), outline(zero, #none, transparent)}),
    selector("::-webkit-slider-thumb", thumb),
    selector("::-moz-range-thumb", thumb),
    selector("::-ms-thumb", thumb),
  })

  @react.component
  let make = (~name=?) => <input type_="range" className=css ?name />
}

module Link = {
  let sx_base = {
    open Sx
    [pointer, bg.none, text.color(black), hover([text.color(primary)])]
  }

  let sx_medium = {
    open Sx
    [py.lg, px.md]
  }

  let sx_icon = {
    open Sx
    [border.none, rounded.md, d.flex, flex.row, items.center, selector("svg", [mr.sm])]
  }

  let sx_icon_hover = {
    open Sx
    [hover([bg.color(gray300)])]
  }

  @react.component
  let make = (~text=?, ~active=false, ~target=?, ~sx as uSx=[], ~icon=?, ~href=?) => {
    let (text, sx_icon_hover, sx_size) = switch text {
    | Some(text) => (<span> {React.string(text)} </span>, [], sx_medium)
    | None => (React.null, sx_icon_hover, [])
    }
    let (sx_icon, icon_svg) = switch icon {
    | Some(svg) => (sx_icon, svg)
    | None => ([], React.null)
    }
    let sx = Array.concat(list{
      uSx,
      sx_base,
      sx_size,
      sx_icon,
      sx_icon_hover,
      if active {
        [Sx.text.color(Sx.primary)]
      } else {
        []
      },
    })
    <a className={Sx.make(sx)} ?href ?target> icon_svg text </a>
  }
}

module Heading = {
  @react.component
  let make = (~level=#h2, ~align=#left, ~sx as uSx=[], ~text) => {
    let sx = {
      open Sx
      [
        w.full,
        d.block,
        Sx.text.sans,
        Sx.text.extrabold,
        leadingRelaxed,
        unsafe("marginTop", "0.4em"),
        unsafe("marginBottom", "0.2em"),
      ]
    }
    let sx = switch align {
    | #left => sx
    | #right => Array.append([Sx.text.right], sx)
    | #center => Array.append([Sx.text.center], sx)
    }
    let className = Sx.make(Array.append(sx, uSx))
    switch level {
    | #h1 => <h1 className> {React.string(text)} </h1>
    | #h2 => <h2 className> {React.string(text)} </h2>
    | #h3 => <h3 className> {React.string(text)} </h3>
    | #h4 => <h4 className> {React.string(text)} </h4>
    | #h5 => <h5 className> {React.string(text)} </h5>
    }
  }
}

module Text = {
  @react.component
  let make = (
    ~sx as uSx=[],
    ~weight=?,
    ~uppercase=?,
    ~align=#left,
    ~size=?,
    ~color=?,
    ~children,
  ) => {
    let sx = Array.append([Sx.text.sans, Sx.leadingNormal], uSx)
    let sx = Array.append([Sx.with_some(Sx.text.color, color)], sx)
    let sx = Array.append([Sx.with_some(flag => flag ? Sx.text.upper : Sx.empty, uppercase)], sx)
    let sx = switch size {
    | None => sx
    | Some(#xs) => Array.append([Sx.text.xs], sx)
    | Some(#sm) => Array.append([Sx.text.sm], sx)
    | Some(#md) => Array.append([Sx.text.md], sx)
    | Some(#lg) => Array.append([Sx.text.lg], sx)
    | Some(#xl) => Array.append([Sx.text.xl], sx)
    | Some(#xl2) => Array.append([Sx.text.xl2], sx)
    | Some(#xl3) => Array.append([Sx.text.xl3], sx)
    | Some(#xl4) => Array.append([Sx.text.xl4], sx)
    | Some(#xl5) => Array.append([Sx.text.xl5], sx)
    | Some(#xl6) => Array.append([Sx.text.xl6], sx)
    }
    let sx = switch weight {
    | None => sx
    | Some(#hairline) => Array.append([Sx.text.hairline], sx)
    | Some(#thin) => Array.append([Sx.text.thin], sx)
    | Some(#light) => Array.append([Sx.text.light], sx)
    | Some(#normal) => Array.append([Sx.text.normal], sx)
    | Some(#medium) => Array.append([Sx.text.medium], sx)
    | Some(#semibold) => Array.append([Sx.text.semibold], sx)
    | Some(#bold) => Array.append([Sx.text.bold], sx)
    | Some(#extrabold) => Array.append([Sx.text.extrabold], sx)
    | Some(#black) => Array.append([Sx.text.black], sx)
    }
    let sx = switch align {
    | #left => sx
    | #right => Array.append([Sx.text.right], sx)
    | #center => Array.append([Sx.text.center], sx)
    }
    <span className={Sx.make(sx)}> children </span>
  }
}

module Table = {
  let color = Sx.gray300

  let sx = {
    open Sx
    [
      w.full,
      text.left,
      borderCollapse,
      border.xs,
      border.color(color),
      selector("thead > tr", [borderB.sm, borderB.color(color)]),
      selector("thead tr > th", [px.lg, py.sm, text.left]),
    ]
  }

  @react.component
  let make = (~sx as uSx=[], ~children) =>
    <table className={Sx.make(Array.append(sx, uSx))}> children </table>

  module H = {
    let sx = {
      open Sx
      [px.lg, py.sm, text.left]
    }

    @react.component
    let make = (~sx as uSx=[], ~children) =>
      <th className={Sx.make(Array.append(sx, uSx))}> children </th>
  }

  module Row = {
    let sx = {
      open Sx
      [borderB.xs, border.color(color)]
    }

    @react.component
    let make = (~sx as uSx=[], ~children) =>
      <tr className={Sx.make(Array.append(sx, uSx))}> children </tr>
  }

  module Col = {
    let sx = {
      open Sx
      [px.lg, py.sm]
    }

    @react.component
    let make = (~sx as uSx=[], ~children) =>
      <td className={Sx.make(Array.append(sx, uSx))}> children </td>
  }
}

module Code = {
  let sx = {
    open Sx
    [rounded.md, p.xl, bg.color(gray100), text.mono]
  }
  @react.component
  let make = (~sx as uSx=[], ~content) =>
    <pre className={Sx.make(Array.append(sx, Array.append(Block.sx, uSx)))}>
      {React.string(content)}
    </pre>
}

module Modal = {
  let overlaySx = {
    open Sx
    [
      absolute,
      t.zero,
      r.zero,
      b.zero,
      l.zero,
      d.flex,
      items.start,
      justify.center,
      z.overlay,
      before([Sx.unsafe("content", ""), w.full, h.full, fixed, opacity75, bg.color(black)]),
    ]
  }

  let contentSx = {
    open Sx
    [
      [Css.maxHeight(#calc(#sub, #percent(100.0), #rem(4.0)))],
      boxBorder,
      unsafe("maxWidth", "66.66%"),
      mt.xl4,
      absolute,
      bg.color(white),
      rounded.md,
      overflow.auto,
    ]
  }

  @react.component
  let make = (~title=?, ~sx as uSx=[], ~children) =>
    <div className={Sx.make(overlaySx)}>
      <div className={Sx.make(Array.append(contentSx, uSx))}>
        <Block sx=[Sx.p.xl2]>
          {Rx.maybe(title, text => <Heading sx=[Sx.mt.zero] text level=#h2 />)} children
        </Block>
      </div>
    </div>
}

module Showcase = {
  let data = [
    [20070101.0, 60.0],
    [20070102.0, 66.0],
    [20070103.0, 62.0],
    [20070104.0, 57.0],
    [20070105.0, 54.0],
    [20070106.0, 55.0],
  ]

  @react.component
  let make = () => {
    let (flag, setFlag) = React.useState(() => false)
    <Column sx=[Sx.p.xl]>
      <Column spacing=Sx.md>
        <Heading level=#h1 text="Heading level 1" />
        <Heading level=#h2 text="Heading level 2" />
        <Heading level=#h3 text="Heading level 3" />
        <Heading level=#h4 text="Heading level 4" />
        <Heading level=#h5 text="Heading level 5" />
      </Column>
      <Heading level=#h1 text="Text" />
      <Column spacing=Sx.xl>
        <Text> {Rx.string("A simple text component")} </Text>
        <Text>
          {Rx.string(
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
          )}
        </Text>
        <Message sx=[Sx.text.xl] text="Colorless green ideas sleep furiously." />
      </Column>
      <Heading level=#h1 text="Buttons" />
      <Column>
        <Row spacing=Sx.xl4 alignY=#center alignX=#center>
          <Button text="Simple" />
          <Button text="Smaller!" size=#small />
          <Button text="With icon" icon=Icon.alarm />
          <Button text="Click me!" size=#small icon=Icon.layers />
          <Button icon=Icon.layers />
        </Row>
        <Code
          content=`<Button text="Simple" />
<Button text="Smaller!" size=\`small />
<Button text="With icon" icon=Icon.alarm />
<Button text="Click me!" size=\`small icon=Icon.layers />
<Button icon=Icon.layers />`
        />
      </Column>
      <Heading level=#h1 text="Input and controls" />
      <Column sx=[Sx.w.half] spacing=Sx.xl>
        <Slider />
        <Row spacing=Sx.xl>
          <Radio
            label="Something" name="radio" checked={!flag} onChange={_ => setFlag(_ => !flag)}
          />
          <Radio
            label="Something better" name="radio" checked=flag onChange={_ => setFlag(_ => !flag)}
          />
        </Row>
        <Field label="Switch"> <Switch /> </Field>
        <Row spacing=Sx.xl>
          <Field label="Unchecked"> <Checkbox name="checkbox" /> </Field>
          <Field label="Checked"> <Checkbox name="checkbox" defaultChecked=true /> </Field>
        </Row>
        <Field label="Field"> <Input placeholder="Input" /> </Field>
        <Field label="Select">
          <Select defaultValue="a" onChange=ignore placeholder="Options...">
            <option value="a"> {Rx.string("a")} </option>
            <option> {Rx.string("b")} </option>
            <option> {Rx.string("c")} </option>
          </Select>
        </Field>
        <Field label="Textarea"> <Textarea placeholder="Textarea" /> </Field>
        <LineGraph data labels=["date", "value"] />
      </Column>
    </Column>
  }
}
