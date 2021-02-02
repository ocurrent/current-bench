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

exception StopIteration
let arrayFindRev = (arr, pred) => {
  let len = Belt.Array.length(arr)
  let out = ref(None)
  try {
    for i in len - 1 downto 0 {
      let item = Belt.Array.getExn(arr, i)
      if pred(item) {
        out := Some(item)
        raise(StopIteration)
      }
    }
  } catch {
  | StopIteration => ()
  }
  out.contents
}
