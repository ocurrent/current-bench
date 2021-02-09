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

module Array = {
  let findRev = (arr, pred) => {
    let len = Belt.Array.length(arr)
    let rec loop = (i, out) =>
      if i == -1 {
        out
      } else {
        let item = Belt.Array.getExn(arr, i)
        pred(item) ? Some(item) : loop(i - 1, None)
      }
    loop(len - 1, None)
  }

  let findIndexRev = (arr, pred) => {
    let len = Belt.Array.length(arr)
    let rec loop = (i, out) =>
      if i == -1 {
        out
      } else {
        let item = Belt.Array.getExn(arr, i)
        pred(item) ? Some(i) : loop(i - 1, None)
      }
    loop(len - 1, None)
  }

  let push = (arr, item) => {
    ignore(Js.Array.push(item, arr))
    arr
  }

  let last = arr => Belt.Array.get(arr, Belt.Array.length(arr) - 1)
  let lastExn = arr => Belt.Array.getExn(arr, Belt.Array.length(arr) - 1)
}
