let getMetricPrefix = metricName =>
  switch String.split_on_char('/', metricName) {
  | list{prefix, _} => Some(prefix)
  | _ => None
  }

let groupMetricNamesByPrefix = dataByMetricName =>
  dataByMetricName
  ->Belt.Map.String.keysToArray
  ->Belt.Array.reduce(Belt.Map.String.empty, (acc, key) =>
    switch getMetricPrefix(key) {
    | Some(prefix) =>
      let arr = Belt.Map.String.getWithDefault(acc, prefix, [])
      let _ = Js.Array.push(key, arr)
      Belt.Map.String.set(acc, prefix, arr)
    | None => acc
    }
  )
