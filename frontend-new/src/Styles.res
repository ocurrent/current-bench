let sidebarSx = {
  open Sx
  [
    d.none,
    media.md([
      fixed,
      insetY.zero,
      overflowY.visible,
      w.xl5,
      d.block,
      borderR.xs,
      borderR.color(Sx.gray300),
      d.flex,
      flex.col,
      p.lg,
      bg.color(white),
    ]),
  ]
}

let mainSx = [Sx.w.full, Sx.px.xl2, Sx.py.xl2, Sx.media.md([Sx.ml.xl5])]

let topbarSx = [
  Sx.w.full,
  Sx.media.md([Sx.ml.xl5]),
  Sx.borderB.xs,
  Sx.borderB.color(Sx.gray300),
  Sx.minH.xl3,
  Sx.p.lg,
  Sx.d.flex,
  Sx.items.center,
]
