let sizeUnits = ["bytes", "kb", "mb", "gb", "tb", "pb", "eb", "zb", "yb"]
// FIXME: Should include other units too?!
let sizeRegex = %re("/(gb|mb|kb|bytes)\w*/i")
let isSize = x => Js.Re.exec_(sizeRegex, x)->Belt.Option.isSome

let getUnitsIndex = units => {
  let reMatch = Js.Re.exec_(sizeRegex, units)
  let oldStr = reMatch->Belt.Option.getExn->Js.Re.captures->Belt.Array.getExn(1)->Js.String.make
  Js.Array.findIndex(x => x == oldStr, sizeUnits)
}

let getAdjustedSize = (value, units, unitIndex, unitChange) => {
  let changeFactor = Js.Math.pow_float(~base=10.0, ~exp=(unitChange * 3)->Js.Int.toFloat)
  let newValue =
    (value /. changeFactor)
    ->Js.Float.toFixedWithPrecision(~digits=2)
    ->Belt.Float.fromString
    ->Belt.Option.getExn
  let newUnitIndex = unitIndex + unitChange
  let oldStr = Belt.Array.getExn(sizeUnits, unitIndex)
  let newStr = Belt.Array.getExn(sizeUnits, newUnitIndex)
  let newUnit = Js.String.replace(oldStr, newStr, units)
  (newValue, newUnit)
}

let formatSize = (value, units) => {
  let exp = Js.Math.log10(value)->Js.Math.floor_int
  let unitChange = exp / 3
  let unitIndex = getUnitsIndex(units)
  getAdjustedSize(value, units, unitIndex, unitChange)
}

let changeSizeUnits = (value, units, newUnits) => {
  let oldUnitIndex = getUnitsIndex(units)
  let newUnitIndex = getUnitsIndex(newUnits)
  let unitChange = newUnitIndex - oldUnitIndex
  let (value_, _) = getAdjustedSize(value, units, oldUnitIndex, unitChange)
  value_
}

let adjustSize = (timeseries: BenchmarkData.timeseries, units: LineGraph.DataRow.units) => {
  let avgs = Belt.Array.map(timeseries, val => Obj.magic(val[1])[1])
  let maxValue = Array.fold_left((a, b) => a < b ? b : a, 0., avgs)
  let (_, newUnits) = formatSize(maxValue, units)
  let adjustedTimeseries = Belt.Array.map(timeseries, valueWithTime => {
    let (time, value) = Obj.magic(valueWithTime)
    let adjustedValues = Belt.Array.map(value, v =>
      Obj.magic(v) == Js.null ? v : changeSizeUnits(v, units, newUnits)
    )
    Obj.magic([time, adjustedValues])
  })
  (adjustedTimeseries, newUnits)
}

let adjust = (data: BenchmarkData.t) => {
  data->Belt.Map.String.mapWithKey((_, (testIndex, dataByMetricName)) => {
    let adjustedDataByMetricName = dataByMetricName->Belt.Map.String.mapWithKey((
      _,
      (timeseries, metadata),
    ) => {
      let isSizeMetric = switch Belt.Array.size(metadata) {
      | 0 => false
      | _ => isSize(metadata[0]["units"])
      }
      switch isSizeMetric {
      | true => {
          let units = metadata[0]["units"]
          let (ts, newUnits) = adjustSize(timeseries, units)
          let md =
            metadata->Belt.Array.map(x =>
              {"commit": x["commit"], "runAt": x["runAt"], "units": newUnits}
            )
          (ts, md)
        }
      | false => (timeseries, metadata)
      }
    })
    (testIndex, adjustedDataByMetricName)
  })
}
