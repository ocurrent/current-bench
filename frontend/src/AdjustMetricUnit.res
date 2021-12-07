let isSize = x => Js.Re.exec_(%re("/(gb|mb|kb|bytes)\w*/i"), x)->Belt.Option.isSome

let formatSize = (value, units) => {
  let unitArr = ["bytes", "kb", "mb", "gb", "tb", "pb", "eb", "zb", "yb"]
  // exp_ is the exponent value derived from value
  // exp tracks the unit change (which is a factor of 3)
  // mod_exp is the value tracking exp_ % 3 which is multiplied to fractional part
  let exp_ = Js.Math.log10(value)->Js.Math.floor_int
  let exp = exp_ / 3
  let mod_exp = mod(exp_, 3)->Belt.Int.toFloat
  let newValue =
    Js.Math.pow_float(~base=10.0, ~exp=Js.Math.log10(value) -. Js.Int.toFloat(exp_))
    ->(x => x *. Js.Math.pow_float(~base=10.0, ~exp=mod_exp))
    ->Js.Float.toFixedWithPrecision(~digits=2)
    ->Belt.Float.fromString
    ->Belt.Option.getExn

  let reMatch = Js.Re.exec_(%re("/(gb|mb|kb|bytes)\w*/i"), units)
  let startIndex = reMatch->Belt.Option.getExn->Js.Re.index
  let endIndex =
    startIndex +
    reMatch
    ->Belt.Option.getExn
    ->Js.Re.captures
    ->Belt.Array.getExn(1)
    ->Js.String.make
    ->Js.String.length
  let oldStr = Js.String.substring(~from=startIndex, ~to_=endIndex, units)
  // unitArrIndex <- index of the regex match in unitArr
  let unitArrIndex = Js.Array.findIndex(x => x == oldStr, unitArr)
  let newStr = Belt.Array.getExn(unitArr, unitArrIndex + exp)
  let newUnit = Js.String.replace(oldStr, newStr, units)

  (newValue, newUnit)
}

let format = (value, units) => {
  switch value {
  | Current_bench_json.Latest.Float(value) if isSize(units) =>
    let (value, units) = formatSize(value, units)
    (Current_bench_json.Latest.Float(value), units)
  | _ => (value, units)
  }
}
