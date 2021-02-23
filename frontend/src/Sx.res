type color = Css.Types.Color.t

type sizes = {
  xs: int,
  sm: int,
  md: int,
  lg: int,
  xl: int,
  xl2: int,
  xl3: int,
  xl4: int,
  xl5: int,
  xl6: int,
  xl7: int,
  xl8: int,
}

type fontSizes = {
  xs: int,
  sm: int,
  md: int,
  lg: int,
  xl: int,
  xl2: int,
  xl3: int,
  xl4: int,
  xl5: int,
  xl6: int,
}

type colors = {
  primary: color,
  secondary: color,
  lightGray: color,
}

type borderSizes = {
  xs: int,
  sm: int,
  md: int,
  lg: int,
  xl: int,
}

type theme = {
  space: sizes,
  fontSizes: fontSizes,
  colors: colors,
  borderSizes: borderSizes,
}

module Make = (
  Theme: {
    let theme: theme
  },
) => {
  type t = array<Css.rule>

  // This is the custom theme provided as configuration.
  let theme = Theme.theme

  Css.global("*", list{Css.boxSizing(#borderBox)})

  let empty: t = []

  let flatten: array<array<'a>> => list<'a> = xs => Array.to_list(Array.concat(Array.to_list(xs)))

  let on = (flag, x) =>
    if flag {
      x
    } else {
      empty
    }

  let with_some = (f, opt) =>
    switch opt {
    | Some(x) => f(x)
    | None => empty
    }

  let on_some = (x, opt) =>
    switch opt {
    | Some(_) => x
    | None => empty
    }

  let make: array<t> => string = xs => Css.style(flatten(xs))

  let css = xs => xs
  let unsafe = (key, value) => [Css.unsafe(key, value)]

  // Selectors

  let body = xs => Css.global("body", flatten(xs))

  let global = (selector, styles) => Css.global(selector, flatten(styles))

  let focus = xs => [Css.focus(flatten(xs))]
  let before = xs => [Css.before(flatten(xs))]
  let after = xs => [Css.after(flatten(xs))]
  let hover = xs => [Css.hover(flatten(xs))]
  let active = xs => [Css.active(flatten(xs))]
  let invalid = xs => [Css.invalid(flatten(xs))]
  let selector = (s, xs) => [Css.selector(s, flatten(xs))]
  let checked = xs => [Css.checked(flatten(xs))]
  let placeholder = xs => [Css.placeholder(flatten(xs))]

  // Responsive media selectors

  type media = {
    sm: array<t> => t,
    md: array<t> => t,
    lg: array<t> => t,
    xl: array<t> => t,
  }

  let media = {
    sm: xs => [Css.media("(min-width: 640px)", flatten(xs))],
    md: xs => [Css.media("(min-width: 768px)", flatten(xs))],
    lg: xs => [Css.media("(min-width: 1024px)", flatten(xs))],
    xl: xs => [Css.media("(min-width: 1280px)", flatten(xs))],
  }

  // Text

  type text = {
    // Sizes
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    xl2: t,
    xl3: t,
    xl4: t,
    xl5: t,
    xl6: t,
    // Alignment
    left: t,
    right: t,
    center: t,
    justify: t,
    // Color
    color: color => t,
    // Fonts style
    capital: t,
    upper: t,
    sans: t,
    mono: t,
    hairline: t,
    thin: t,
    light: t,
    normal: t,
    medium: t,
    semibold: t,
    bold: t,
    extrabold: t,
    black: t,
    italic: t,
    noUnderline: t,
    underline: t,
    lineThrough: t,
  }

  let text = {
    xs: [Css.fontSize(#px(theme.fontSizes.xs))],
    sm: [Css.fontSize(#px(theme.fontSizes.sm))],
    md: [Css.fontSize(#px(theme.fontSizes.md))],
    lg: [Css.fontSize(#px(theme.fontSizes.lg))],
    xl: [Css.fontSize(#px(theme.fontSizes.xl))],
    xl2: [Css.fontSize(#px(theme.fontSizes.xl2))],
    xl3: [Css.fontSize(#px(theme.fontSizes.xl3))],
    xl4: [Css.fontSize(#px(theme.fontSizes.xl4))],
    xl5: [Css.fontSize(#px(theme.fontSizes.xl5))],
    xl6: [Css.fontSize(#px(theme.fontSizes.xl6))],
    left: [Css.textAlign(#left)],
    right: [Css.textAlign(#right)],
    center: [Css.textAlign(#center)],
    justify: [Css.textAlign(#justify)],
    color: color => [Css.color(color)],
    capital: [Css.textTransform(#capitalize)],
    upper: [Css.textTransform(#uppercase)],
    sans: [
      Css.fontFamily(
        #custom(`system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif`),
      ),
    ],
    mono: [Css.fontFamily(#custom("Menlo, monospace"))],
    hairline: [Css.fontWeight(#num(100))],
    thin: [Css.fontWeight(#num(200))],
    light: [Css.fontWeight(#num(300))],
    normal: [Css.fontWeight(#num(400))],
    medium: [Css.fontWeight(#num(500))],
    semibold: [Css.fontWeight(#num(600))],
    bold: [Css.fontWeight(#num(700))],
    extrabold: [Css.fontWeight(#num(800))],
    black: [Css.fontWeight(#num(900))],
    italic: [Css.fontStyle(#italic)],
    noUnderline: [Css.textDecoration(#none)],
    underline: [Css.textDecoration(#underline)],
    lineThrough: [Css.textDecoration(#lineThrough)],
  }

  // Flex

  type flex = {
    none: t,
    col: t,
    colRev: t,
    row: t,
    rowRev: t,
    wrap: t,
    noWrap: t,
    wrapRev: t,
    grow: int => t,
  }

  let flex = {
    none: [Css.flex(#none)],
    col: [Css.flexDirection(#column)],
    colRev: [Css.flexDirection(#columnReverse)],
    row: [Css.flexDirection(#row)],
    rowRev: [Css.flexDirection(#rowReverse)],
    wrap: [Css.flexWrap(#wrap)],
    noWrap: [Css.flexWrap(#nowrap)],
    wrapRev: [Css.flexWrap(#wrapReverse)],
    grow: n => [Css.flexGrow(float_of_int(n))],
  }

  // Display

  type d = {
    flex: t,
    inlineFlex: t,
    none: t,
    block: t,
    inlineBlock: t,
    table: t,
    cell: t,
  }

  let d = {
    none: [Css.display(#none)],
    block: [Css.display(#block)],
    inlineBlock: [Css.display(#inlineBlock)],
    table: [Css.display(#table)],
    cell: [Css.display(#tableCell)],
    flex: [Css.display(#flex)],
    inlineFlex: [Css.display(#inlineFlex)],
  }

  // Border

  type border = {
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    none: t,
    solid: t,
    double: t,
    dashed: t,
    dotted: t,
    color: color => t,
  }

  let _border = (~borderStyle, ~borderWidth, ~borderColor) => {
    none: [borderStyle(#none)],
    xs: [borderStyle(#solid), borderWidth(#px(theme.borderSizes.xs))],
    sm: [borderStyle(#solid), borderWidth(#px(theme.borderSizes.sm))],
    md: [borderStyle(#solid), borderWidth(#px(theme.borderSizes.md))],
    lg: [borderStyle(#solid), borderWidth(#px(theme.borderSizes.lg))],
    xl: [borderStyle(#solid), borderWidth(#px(theme.borderSizes.xl))],
    solid: [borderStyle(#solid)],
    dashed: [borderStyle(#dashed)],
    dotted: [borderStyle(#dotted)],
    double: [borderStyle(#double)],
    color: color => [borderColor(color)],
  }

  let border = _border(
    ~borderStyle=Css.borderStyle,
    ~borderWidth=Css.borderWidth,
    ~borderColor=Css.borderColor,
  )

  let borderT = _border(
    ~borderStyle=Css.borderTopStyle,
    ~borderWidth=Css.borderTopWidth,
    ~borderColor=Css.borderTopColor,
  )

  let borderR = _border(
    ~borderStyle=Css.borderRightStyle,
    ~borderWidth=Css.borderRightWidth,
    ~borderColor=Css.borderRightColor,
  )

  let borderB = _border(
    ~borderStyle=Css.borderBottomStyle,
    ~borderWidth=Css.borderBottomWidth,
    ~borderColor=Css.borderBottomColor,
  )

  let borderL = _border(
    ~borderStyle=Css.borderLeftStyle,
    ~borderWidth=Css.borderLeftWidth,
    ~borderColor=Css.borderLeftColor,
  )

  let borderCollapse = [Css.borderCollapse(#collapse)]
  let borderSeparate = [Css.borderCollapse(#separate)]

  // Background

  type bg = {
    none: t,
    transparent: t,
    color: color => t,
  }

  let bg = {
    none: [Css.background(#none)],
    transparent: [Css.backgroundColor(#transparent)],
    color: color => [Css.backgroundColor(color)],
  }

  // Container

  let container: t = [
    Css.width(#percent(100.0)),
    Css.media("(max-width: 640px)", list{Css.maxWidth(#px(640))}),
    Css.media("(max-width: 768px)", list{Css.maxWidth(#px(768))}),
    Css.media("(max-width: 1024px)", list{Css.maxWidth(#px(1024))}),
    Css.media("(max-width: 1536px)", list{Css.maxWidth(#px(1536))}),
  ]

  // Margin

  type m = {
    zero: t,
    auto: t,
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    xl2: t,
    xl3: t,
    xl4: t,
    xl5: t,
    xl6: t,
  }

  let _m = margin => {
    zero: [margin(#zero)],
    auto: [margin(#auto)],
    xs: [margin(#px(theme.space.xs))],
    sm: [margin(#px(theme.space.sm))],
    md: [margin(#px(theme.space.md))],
    lg: [margin(#px(theme.space.lg))],
    xl: [margin(#px(theme.space.xl))],
    xl2: [margin(#px(theme.space.xl2))],
    xl3: [margin(#px(theme.space.xl3))],
    xl4: [margin(#px(theme.space.xl4))],
    xl5: [margin(#px(theme.space.xl5))],
    xl6: [margin(#px(theme.space.xl6))],
  }

  let m = _m(Css.margin)
  let mt = _m(Css.marginTop)
  let mr = _m(Css.marginRight)
  let mb = _m(Css.marginBottom)
  let ml = _m(Css.marginLeft)

  let _m2 = (margin1, margin2) => {
    zero: [margin1(#zero), margin2(#zero)],
    auto: [margin1(#auto), margin2(#auto)],
    xs: [margin1(#px(theme.space.xs)), margin2(#px(theme.space.xs))],
    sm: [margin1(#px(theme.space.sm)), margin2(#px(theme.space.sm))],
    md: [margin1(#px(theme.space.md)), margin2(#px(theme.space.md))],
    lg: [margin1(#px(theme.space.lg)), margin2(#px(theme.space.lg))],
    xl: [margin1(#px(theme.space.xl)), margin2(#px(theme.space.xl))],
    xl2: [margin1(#px(theme.space.xl2)), margin2(#px(theme.space.xl2))],
    xl3: [margin1(#px(theme.space.xl3)), margin2(#px(theme.space.xl3))],
    xl4: [margin1(#px(theme.space.xl4)), margin2(#px(theme.space.xl4))],
    xl5: [margin1(#px(theme.space.xl5)), margin2(#px(theme.space.xl5))],
    xl6: [margin1(#px(theme.space.xl6)), margin2(#px(theme.space.xl6))],
  }

  let my = _m2(Css.marginTop, Css.marginBottom)
  let mx = _m2(Css.marginLeft, Css.marginRight)

  // Padding

  type p = {
    zero: t,
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    xl2: t,
    xl3: t,
    xl4: t,
    xl5: t,
    xl6: t,
  }

  let _p = padding => {
    zero: [padding(#zero)],
    xs: [padding(#px(theme.space.xs))],
    sm: [padding(#px(theme.space.sm))],
    md: [padding(#px(theme.space.md))],
    lg: [padding(#px(theme.space.lg))],
    xl: [padding(#px(theme.space.xl))],
    xl2: [padding(#px(theme.space.xl2))],
    xl3: [padding(#px(theme.space.xl3))],
    xl4: [padding(#px(theme.space.xl4))],
    xl5: [padding(#px(theme.space.xl5))],
    xl6: [padding(#px(theme.space.xl6))],
  }

  let p = _p(Css.padding)
  let pt = _p(Css.paddingTop)
  let pr = _p(Css.paddingRight)
  let pb = _p(Css.paddingBottom)
  let pl = _p(Css.paddingLeft)

  let _p2 = (padding1, padding2) => {
    zero: [padding1(#zero), padding2(#zero)],
    xs: [padding1(#px(theme.space.xs)), padding2(#px(theme.space.xs))],
    sm: [padding1(#px(theme.space.sm)), padding2(#px(theme.space.sm))],
    md: [padding1(#px(theme.space.md)), padding2(#px(theme.space.md))],
    lg: [padding1(#px(theme.space.lg)), padding2(#px(theme.space.lg))],
    xl: [padding1(#px(theme.space.xl)), padding2(#px(theme.space.xl))],
    xl2: [padding1(#px(theme.space.xl2)), padding2(#px(theme.space.xl2))],
    xl3: [padding1(#px(theme.space.xl3)), padding2(#px(theme.space.xl3))],
    xl4: [padding1(#px(theme.space.xl4)), padding2(#px(theme.space.xl4))],
    xl5: [padding1(#px(theme.space.xl5)), padding2(#px(theme.space.xl5))],
    xl6: [padding1(#px(theme.space.xl6)), padding2(#px(theme.space.xl6))],
  }

  let py = _p2(Css.paddingTop, Css.paddingBottom)
  let px = _p2(Css.paddingLeft, Css.paddingRight)

  // Inset

  type inset = {
    auto: t,
    zero: t,
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    xl2: t,
    xl3: t,
    xl4: t,
    xl5: t,
    xl6: t,
  }

  let _inset = (dirs): inset => {
    auto: Array.map(dir => dir(#auto), dirs),
    zero: Array.map(dir => dir(#zero), dirs),
    xs: Array.map(dir => dir(#px(theme.space.xs)), dirs),
    sm: Array.map(dir => dir(#px(theme.space.sm)), dirs),
    md: Array.map(dir => dir(#px(theme.space.md)), dirs),
    lg: Array.map(dir => dir(#px(theme.space.lg)), dirs),
    xl: Array.map(dir => dir(#px(theme.space.xl)), dirs),
    xl2: Array.map(dir => dir(#px(theme.space.xl2)), dirs),
    xl3: Array.map(dir => dir(#px(theme.space.xl3)), dirs),
    xl4: Array.map(dir => dir(#px(theme.space.xl4)), dirs),
    xl5: Array.map(dir => dir(#px(theme.space.xl5)), dirs),
    xl6: Array.map(dir => dir(#px(theme.space.xl6)), dirs),
  }

  let inset = _inset([Css.left, Css.right, Css.top, Css.bottom])

  let t = _inset([Css.top])
  let r = _inset([Css.right])
  let b = _inset([Css.bottom])
  let l = _inset([Css.left])

  let insetX = _inset([Css.left, Css.right])
  let insetY = _inset([Css.top, Css.bottom])

  // Size

  type size = {
    zero: t,
    auto: t,
    full: t,
    screen: t,
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    xl2: t,
    xl3: t,
    xl4: t,
    xl5: t,
    xl6: t,
    xl7: t,
    xl8: t,
    half: t,
    third: t,
    quarter: t,
    fifth: t,
    sixth: t,
  }

  type sizeMinMax = {
    zero: t,
    full: t,
    screen: t,
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    xl2: t,
    xl3: t,
    xl4: t,
    xl5: t,
    xl6: t,
    xl7: t,
    xl8: t,
    half: t,
    third: t,
    quarter: t,
    fifth: t,
    sixth: t,
  }

  let _wh = (wh, wOrH): size => {
    zero: [wh(#zero)],
    auto: [wh(#auto)],
    full: [wh(#percent(100.0))],
    screen: [
      wh(
        switch wOrH {
        | #w => #vw(100.0)
        | #h => #vh(100.0)
        },
      ),
    ],
    xs: [wh(#px(theme.space.xs))],
    sm: [wh(#px(theme.space.sm))],
    md: [wh(#px(theme.space.md))],
    lg: [wh(#px(theme.space.lg))],
    xl: [wh(#px(theme.space.xl))],
    xl2: [wh(#px(theme.space.xl2))],
    xl3: [wh(#px(theme.space.xl3))],
    xl4: [wh(#px(theme.space.xl4))],
    xl5: [wh(#px(theme.space.xl5))],
    xl6: [wh(#px(theme.space.xl6))],
    xl7: [wh(#px(theme.space.xl7))],
    xl8: [wh(#px(theme.space.xl8))],
    half: [wh(#percent(50.0))],
    third: [wh(#percent(33.333333))],
    quarter: [wh(#percent(25.0))],
    fifth: [wh(#percent(20.0))],
    sixth: [wh(#percent(16.666667))],
  }

  let w = _wh(Css.width, #w)
  let h = _wh(Css.height, #h)

  let _minMaxWh = (wh): sizeMinMax => {
    zero: [wh(#zero)],
    full: [wh(#percent(100.0))],
    screen: [wh(#vw(100.0))],
    xs: [wh(#px(theme.space.xs))],
    sm: [wh(#px(theme.space.sm))],
    md: [wh(#px(theme.space.md))],
    lg: [wh(#px(theme.space.lg))],
    xl: [wh(#px(theme.space.xl))],
    xl2: [wh(#px(theme.space.xl2))],
    xl3: [wh(#px(theme.space.xl3))],
    xl4: [wh(#px(theme.space.xl4))],
    xl5: [wh(#px(theme.space.xl5))],
    xl6: [wh(#px(theme.space.xl6))],
    xl7: [wh(#px(theme.space.xl7))],
    xl8: [wh(#px(theme.space.xl8))],
    half: [wh(#percent(50.0))],
    third: [wh(#percent(33.333333))],
    quarter: [wh(#percent(25.0))],
    fifth: [wh(#percent(20.0))],
    sixth: [wh(#percent(16.666667))],
  }

  let maxW = _minMaxWh(Css.maxWidth)
  let maxH = _minMaxWh(Css.maxHeight)

  let minW = _minMaxWh(Css.minWidth)
  let minH = _minMaxWh(Css.minHeight)

  // Z-index

  type z = {
    auto: t,
    low: t,
    normal: t,
    high: t,
    dropdown: t,
    sticky: t,
    fixed: t,
    overlay: t,
    modal: t,
    popover: t,
    tooltip: t,
  }

  let z = {
    auto: [Css.unsafe("z-index", "auto")],
    low: [Css.zIndex(-10)],
    normal: [Css.zIndex(0)],
    high: [Css.zIndex(10)],
    dropdown: [Css.zIndex(100)],
    sticky: [Css.zIndex(120)],
    fixed: [Css.zIndex(130)],
    overlay: [Css.zIndex(140)],
    modal: [Css.zIndex(150)],
    popover: [Css.zIndex(160)],
    tooltip: [Css.zIndex(170)],
  }

  // Overflow

  type overflow = {
    auto: t,
    hidden: t,
    visible: t,
    scroll: t,
  }

  let _overflow = f => {
    auto: [f(#auto)],
    hidden: [f(#hidden)],
    visible: [f(#visible)],
    scroll: [f(#scroll)],
  }

  let overflow = _overflow(Css.overflow)
  let overflowX = _overflow(Css.overflowX)
  let overflowY = _overflow(Css.overflowY)

  // Border Radius

  type rounded = {
    none: t,
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    xl2: t,
    xl3: t,
    full: t,
  }

  let _rounded = corner => {
    none: [corner(#zero)],
    xs: [corner(#rem(0.125))],
    sm: [corner(#rem(0.25))],
    md: [corner(#rem(0.375))],
    lg: [corner(#rem(0.5))],
    xl: [corner(#rem(0.75))],
    xl2: [corner(#rem(1.0))],
    xl3: [corner(#rem(1.5))],
    full: [corner(#px(9999))],
  }

  let rounded = _rounded(Css.borderRadius)
  let roundedTL = _rounded(Css.borderTopLeftRadius)
  let roundedTR = _rounded(Css.borderTopRightRadius)
  let roundedBL = _rounded(Css.borderBottomLeftRadius)
  let roundedBR = _rounded(Css.borderBottomRightRadius)

  let _rounded2 = (corner1, corner2) => {
    none: [corner1(#zero), corner2(#zero)],
    xs: [corner1(#rem(0.125)), corner2(#rem(0.125))],
    sm: [corner1(#rem(0.25)), corner2(#rem(0.25))],
    md: [corner1(#rem(0.375)), corner2(#rem(0.375))],
    lg: [corner1(#rem(0.5)), corner2(#rem(0.5))],
    xl: [corner1(#rem(0.75)), corner2(#rem(0.75))],
    xl2: [corner1(#rem(1.0)), corner2(#rem(1.0))],
    xl3: [corner1(#rem(1.5)), corner2(#rem(1.5))],
    full: [corner1(#px(9999)), corner2(#px(9999))],
  }

  let roundedT = _rounded2(Css.borderTopLeftRadius, Css.borderTopRightRadius)
  let roundedR = _rounded2(Css.borderTopRightRadius, Css.borderBottomRightRadius)
  let roundedB = _rounded2(Css.borderBottomLeftRadius, Css.borderBottomRightRadius)
  let roundedL = _rounded2(Css.borderTopLeftRadius, Css.borderBottomLeftRadius)

  // Box Shadow

  type shadow = {
    none: t,
    xs: t,
    sm: t,
    md: t,
    lg: t,
    xl: t,
    xl2: t,
    xl3: t,
    inner: t,
    outline: t,
  }

  let shadow = {
    none: [Css.unsafe("box-shadow", "none")],
    xs: [Css.unsafe("box-shadow", "0 0 0 1px rgba(0, 0, 0, 0.05)")],
    sm: [Css.unsafe("box-shadow", "0 1px 2px 0 rgba(0, 0, 0, 0.05)")],
    md: [
      Css.unsafe("box-shadow", "0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06)"),
    ],
    lg: [
      Css.unsafe(
        "box-shadow",
        "0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)",
      ),
    ],
    xl: [
      Css.unsafe(
        "box-shadow",
        "0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)",
      ),
    ],
    xl2: [
      Css.unsafe(
        "box-shadow",
        "0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)",
      ),
    ],
    xl3: [Css.unsafe("box-shadow", "0 25px 50px -10px rgba(0, 0, 0, 0.25)")],
    inner: [Css.unsafe("box-shadow", "inset 0 2px 4px 0 rgba(0, 0, 0, 0.06)")],
    outline: [Css.unsafe("box-shadow", "0 0 0 3px rgba(66, 153, 225, 0.5)")],
  }

  // Box Alignment

  type justify = {
    start: t,
    center: t,
    end: t,
    between: t,
    around: t,
    evenly: t,
  }

  let justify = {
    start: [Css.justifyContent(#flexStart)],
    center: [Css.justifyContent(#center)],
    end: [Css.justifyContent(#flexEnd)],
    between: [Css.justifyContent(#spaceBetween)],
    around: [Css.justifyContent(#spaceAround)],
    evenly: [Css.justifyContent(#spaceEvenly)],
  }

  type justifyItems = {
    auto: t,
    start: t,
    end: t,
    center: t,
    stretch: t,
  }

  let justifyItems = {
    auto: [Css.unsafe("justify-items", "auto")],
    start: [Css.justifyItems(#start)],
    end: [Css.justifyItems(#end_)],
    center: [Css.justifyItems(#center)],
    stretch: [Css.unsafe("justify-items", "stretch")],
  }

  let justifySelf = {
    auto: [Css.justifySelf(#auto)],
    start: [Css.justifySelf(#start)],
    end: [Css.justifySelf(#end_)],
    center: [Css.justifySelf(#center)],
    stretch: [Css.justifySelf(#stretch)],
  }

  type alignItems = {
    start: t,
    end: t,
    center: t,
    baseline: t,
    stretch: t,
  }

  let items = {
    start: [Css.alignItems(#start)],
    end: [Css.alignItems(#end_)],
    center: [Css.alignItems(#center)],
    baseline: [Css.alignItems(#baseline)],
    stretch: [Css.alignItems(#stretch)],
  }

  type alignSelf = {
    start: t,
    end: t,
    center: t,
    auto: t,
    stretch: t,
  }

  let self: alignSelf = {
    start: [Css.alignSelf(#start)],
    end: [Css.alignSelf(#end_)],
    center: [Css.alignSelf(#center)],
    auto: [Css.alignSelf(#auto)],
    stretch: [Css.alignSelf(#stretch)],
  }

  type content = {
    center: t,
    start: t,
    end: t,
    between: t,
    around: t,
    evenly: t,
  }

  let content = {
    center: [Css.alignContent(#center)],
    start: [Css.alignContent(#start)],
    end: [Css.alignContent(#end_)],
    between: [Css.alignContent(#spaceBetween)],
    around: [Css.alignContent(#spaceAround)],
    evenly: [Css.alignContent(#spaceEvenly)],
  }

  // Position

  let static = [Css.position(#static)]
  let relative = [Css.position(#relative)]
  let absolute = [Css.position(#absolute)]
  let fixed = [Css.position(#fixed)]
  let sticky = [Css.position(#sticky)]

  let box = [Css.boxSizing(#borderBox), Css.display(#block), Css.width(#percent(100.0))]

  // Colors
  let highlight = Css.rgb(239, 239, 254)
  let primary = theme.colors.primary
  let secondary = Css.hex("30c")
  let white = Css.hex("FFFFFF")
  let black = Css.hex("000000")
  let transparent = Css.transparent

  let lightGray = theme.colors.lightGray
  let gray100 = Css.hex("F6F6F6")
  let gray200 = Css.hex("EDF2F7")
  let gray300 = Css.hex("EEE")
  let gray400 = Css.hex("CBD5E0")
  let gray500 = Css.hex("A0AEC0")
  let gray600 = Css.hex("718096")
  let gray700 = Css.hex("4A5568")
  let gray800 = Css.hex("2D3748")
  let gray900 = Css.hex("1A202C")
  let red800 = Css.hex("9B2C2C")
  let red300 = Css.hex("eb102a")
  let green700 = Css.hex("2F855A")
  let green300 = Css.hex("12db69")
  let yellow600 = Css.hex("D69E2E")

  let invisible = [Css.visibility(#hidden)]
  let visible = [Css.visibility(#visible)]

  let appearanceNone = [Css.unsafe("appearance", "none")]

  let scrollingTouch = [Css.unsafe("-webkit-overflow-scrolling", "touch")]
  let scrollingAuto = [Css.unsafe("-webkit-overflow-scrolling", "auto")]

  let zero = #zero
  let xs = #px(theme.space.xs)
  let sm = #px(theme.space.sm)
  let md = #px(theme.space.md)
  let lg = #px(theme.space.lg)
  let xl = #px(theme.space.xl)
  let xl2 = #px(theme.space.xl2)
  let xl3 = #px(theme.space.xl3)
  let xl4 = #px(theme.space.xl4)
  let xl5 = #px(theme.space.xl5)
  let xl6 = #px(theme.space.xl6)

  let boxBorder = [Css.boxSizing(#borderBox)]

  let outlineNone = [Css.outline(zero, #none, Css.transparent)]
  let debug1 = [Css.border(#px(1), #solid, Css.cyan)]
  let debug2 = [Css.border(#px(1), #solid, Css.magenta)]
  let debug = debug1

  // Line height

  let leadingNone = [Css.lineHeight(#abs(1.0))]
  let leadingTight = [Css.lineHeight(#abs(1.25))]
  let leadingSnug = [Css.lineHeight(#abs(1.375))]
  let leadingNormal = [Css.lineHeight(#abs(1.5))]
  let leadingRelaxed = [Css.lineHeight(#abs(1.625))]
  let leadingLoose = [Css.lineHeight(#abs(2.0))]
  let leading3 = [Css.lineHeight(#rem(0.75))]
  let leading4 = [Css.lineHeight(#rem(1.0))]
  let leading5 = [Css.lineHeight(#rem(1.25))]
  let leading6 = [Css.lineHeight(#rem(1.5))]
  let leading7 = [Css.lineHeight(#rem(1.75))]
  let leading8 = [Css.lineHeight(#rem(2.0))]
  let leading9 = [Css.lineHeight(#rem(2.25))]
  let leading10 = [Css.lineHeight(#rem(2.5))]

  let opacity100 = [Css.opacity(1.0)]
  let opacity75 = [Css.opacity(0.75)]
  let opacity50 = [Css.opacity(0.5)]
  let opacity25 = [Css.opacity(0.25)]
  let opacity0 = [Css.opacity(0.0)]

  // Cursor
  let pointer = [Css.cursor(#pointer)]

  let pointerEventsNone = [Css.pointerEvents(#none)]
  let pointerEventsAuto = [Css.pointerEvents(#auto)]
  let pointerEventsInherit = [Css.pointerEvents(#inherit_)]
}

// Default theme.
let default = {
  space: {
    xs: 1,
    sm: 2,
    md: 4,
    lg: 8,
    xl: 16,
    xl2: 32,
    xl3: 64,
    xl4: 128,
    xl5: 256,
    xl6: 512,
    xl7: 1024,
    xl8: 1440,
  },
  fontSizes: {
    xs: 12,
    sm: 14,
    md: 16,
    lg: 18,
    xl: 20,
    xl2: 24,
    xl3: 32,
    xl4: 48,
    xl5: 56,
    xl6: 72,
  },
  colors: {
    primary: Css.rgb(0, 85, 255),
    secondary: Css.hex("30c"),
    lightGray: Css.hex("f6f6f6"),
  },
  borderSizes: {
    xs: 1,
    sm: 2,
    md: 4,
    lg: 6,
    xl: 8,
  },
}

// Default contains the Sx styles with the default theme.
module Default = Make({
  let theme = default
})

// We also include Default in this file to allow people (for now) to use Sx.mr5, etc.
include Default
