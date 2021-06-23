type t = Dom.intersectionObserver

module Entry = {
  type t = Dom.intersectionObserverEntry
  @get external isIntersecting: t => bool = "isIntersecting"
}

type intersectionOption = {
  root: Js.Nullable.t<Dom.element>,
  rootMargin: option<string>,
  threshold: option<array<float>>,
}

@obj
external makeOption: (
  ~root: Js.Nullable.t<Dom.element>=?,
  ~rootMargin: string=?,
  ~threshold: array<float>=?,
  unit,
) => intersectionOption = ""

@new
external make: (@uncurry (array<Entry.t>, t) => unit, intersectionOption) => t =
  "IntersectionObserver"

@send external disconnect: t => unit = "disconnect"
@send external observe: (t, Dom.element) => unit = "observe"
