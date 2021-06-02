
let useIntersection = (
  ref: React.ref<Js.Nullable.t<Dom.element>>,
  options: IntersectionObserver.intersectionOption,
) => {
  let (intersectionObserverEntry, setIntersectionObserverEntry) = React.useState(() => None)

  React.useEffect4(() => {
    switch Js.Nullable.toOption(ref.current) {
    | None => None
    | Some(domRef) => {
        let handler = (entries, _observer) => {
          setIntersectionObserverEntry(_ => Some(entries[0]))
        }

        let observer = IntersectionObserver.make(handler, options)
        let () = IntersectionObserver.observe(observer, domRef)

        Some(
          () => {
            setIntersectionObserverEntry(_ => None)
            let () = IntersectionObserver.disconnect(observer)
          },
        )
      }
    }
  }, (ref.current, options.root, options.rootMargin, options.threshold))

  intersectionObserverEntry
}
