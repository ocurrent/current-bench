// Helper React eXtensions

let null = React.null

let on = (flag, element) => flag ? element : React.null

let option = opt =>
  switch opt {
  | Some(x) => x
  | None => React.null
  }

let onSome = (opt, f) =>
  switch opt {
  | Some(x) => f(x)
  | None => React.null
  }

let onNone = (opt, x) =>
  switch opt {
  | None => x
  | Some(_) => React.null
  }

let float = x => React.string(Js.Float.toString(x))
let int = x => React.string(string_of_int(x))
let bool = x => React.string(string_of_bool(x))
let string = React.string
let text = React.string
let array = (~empty=React.null, xs) => Array.length(xs) == 0 ? empty : React.array(xs)
let list = l => Array.of_list(l)

let eventValue = e => ReactEvent.Form.target(e)["value"]
