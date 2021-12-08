let sizeUnits = ["bytes", "kb", "mb", "gb", "tb", "pb", "eb", "zb", "yb"]
// FIXME: Should include other units too?!
let sizeRegex = %re("/(gb|mb|kb|bytes)\w*/i")
let isSize = x => Js.Re.exec_(sizeRegex, x)->Belt.Option.isSome

let getUnitsIndex = units => {
  let reMatch = Js.Re.exec_(sizeRegex, units)
  let oldStr = reMatch->Belt.Option.getExn->Js.Re.captures->Belt.Array.getExn(1)->Js.String.make
  Js.Array.findIndex(x => x == oldStr, sizeUnits)
}

let formatSize = (value, units) => {
  let exp = Js.Math.log10(value)->Js.Math.floor_int
  let unitChange = exp / 3
  let changeFactor = Js.Math.pow_float(~base=10.0, ~exp=(unitChange * 3)->Js.Int.toFloat)
  let newValue =
    (value /. changeFactor)
    ->Js.Float.toFixedWithPrecision(~digits=2)
    ->Belt.Float.fromString
    ->Belt.Option.getExn
  let unitIndex = getUnitsIndex(units)
  let newUnitIndex = unitIndex + unitChange
  let oldStr = Belt.Array.getExn(sizeUnits, unitIndex)
  let newStr = Belt.Array.getExn(sizeUnits, newUnitIndex)
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
