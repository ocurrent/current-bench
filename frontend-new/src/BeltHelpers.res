open Belt

module MapString = {
  let addToArray = (map: Map.String.t<array<'a>>, k, v): Map.String.t<array<'a>> => {
    let maybeAdd = opt =>
      switch opt {
      | Some(items) =>
        ignore(Js.Array.push(v, items))
        Some(items)
      | None => Some([])
      }
    Map.String.update(map, k, maybeAdd)
  }
}
