open MetricHierarchyHelpers

let sizeUnits = ["kb", "mb", "gb", "tb", "pb", "eb", "zb", "yb"]
let sizeRegex = %re("/(yb|zb|eb|pb|tb|gb|mb|kb)\w*/i")
let isSize = x => Js.Re.exec_(sizeRegex, x)->Belt.Option.isSome

let getUnitsIndex = units => {
  let reMatch = Js.Re.exec_(sizeRegex, units)
  let oldStr = switch reMatch {
  | None => ""
  | Some(match) =>
    switch match->Js.Re.captures->Belt.Array.get(1) {
    | Some(s) => s->Js.String.make
    | None => ""
    }
  }
  Js.Array.findIndex(x => x == oldStr, sizeUnits)
}

let getAdjustedSize = (value, units, unitIndex, unitChange) => {
  open! Js.Math
  let newUnitIndex = unitIndex + unitChange
  let n = Belt.Array.size(sizeUnits)
  let (newUnitIndex, unitChange) = switch newUnitIndex {
  | x if x < 0 => (0, 0 - unitIndex)
  | x if x >= n - 1 => (n - 1, n - 1 - unitIndex)
  | x => (x, unitChange)
  }
  let changeFactor = pow_float(~base=10.0, ~exp=(unitChange * 3)->Js.Int.toFloat)
  let newValue =
    (value /. changeFactor)->Js.Float.toFixedWithPrecision(~digits=2)->Belt.Float.fromString->Belt.Option.getExn
  let oldStr = Belt.Array.get(sizeUnits, unitIndex)
  let newStr = Belt.Array.get(sizeUnits, newUnitIndex)
  switch (oldStr, newStr) {
  | (Some(oldStr), Some(newStr)) => (newValue, Js.String.replace(oldStr, newStr, units))
  | _ => (value, units)
  }
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
  let avgs = Belt.Array.map(timeseries, LineGraph.DataRow.toValue)
  let maxValue = Array.fold_left((a, b) => a < b ? b : a, 0., avgs)
  let (_, newUnits) = formatSize(maxValue, units)
  let adjustedTimeseries = Belt.Array.map(timeseries, value => {
    Belt.Array.map(value, v => Js.Float.isNaN(v) ? v : changeSizeUnits(v, units, newUnits))
  })
  (adjustedTimeseries, newUnits)
}

let adjust = (data: BenchmarkData.t) => {
  data->Belt.Map.String.mapWithKey((_, (testIndex, dataByMetricName)) => {
    let metricNamesByPrefix = groupMetricNamesByPrefix(dataByMetricName)
    let adjustedDataByMetricName = dataByMetricName->Belt.Map.String.mapWithKey((
      metricName,
      (timeseries, metadata),
    ) => {
      let isSizeMetric = switch Belt.Array.size(metadata) {
      | 0 => false
      | _ => isSize(metadata[0].units)
      }
      switch isSizeMetric {
      | true => {
          let prefix = getMetricPrefix(metricName)
          let units = metadata[0].units
          // We concatenate the timeseries for all metrics in the hierarchy to correctly adjust units
          let hierarchyTimeseries = switch prefix {
          | Some(prefix) =>
            let names =
              metricNamesByPrefix
              ->Belt.Map.String.getExn(prefix)
              ->Belt.SortArray.stableSortBy((a, b) => {
                a == metricName ? -1 : b == metricName ? 1 : compare(a, b)
              })
            names
            ->Belt.Array.map(x => {
              let (t, _) = dataByMetricName->Belt.Map.String.getExn(x)
              t
            })
            ->Belt.Array.concatMany
          | None => timeseries
          }
          let (hts, newUnits) = adjustSize(hierarchyTimeseries, units)
          let ts = hts->Belt.Array.slice(~offset=0, ~len=Belt.Array.length(timeseries))
          let md = metadata->Belt.Array.map(x => {...x, units: newUnits})

          (ts, md)
        }
      | false => (timeseries, metadata)
      }
    })
    (testIndex, adjustedDataByMetricName)
  })
}

// Adjust comparisonData units to be same as units of corresponding benchmarks data
let adjustComparisonData = (comparisonData: BenchmarkData.t, data: BenchmarkData.t) => {
  comparisonData->Belt.Map.String.mapWithKey((
    testName,
    (testIndex, comparisonDataByMetricName),
  ) => {
    let adjustedDataByMetricName =
      comparisonDataByMetricName->Belt.Map.String.mapWithKey((
        metricName,
        (timeseries, metadata),
      ) => {
        let isSizeMetric = switch Belt.Array.size(metadata) {
        | 0 => false
        | _ => isSize(metadata[0].units)
        }
        switch isSizeMetric {
        | true => {
            let units = metadata[0].units
            let (_, dataByMetricName) =
              data->Belt.Map.String.getWithDefault(testName, (0, Belt.Map.String.empty))
            let (_, benchmarkMetadata) =
              dataByMetricName->Belt.Map.String.getWithDefault(metricName, ([], []))
            let (ts, newUnits) = switch benchmarkMetadata->Belt.Array.length {
            | 0 => adjustSize(timeseries, units)
            | _ => {
                let newUnits = benchmarkMetadata[0].units
                let adjustedTimeseries = Belt.Array.map(timeseries, value => {
                  Belt.Array.map(value, v =>
                    Js.Float.isNaN(v) ? v : changeSizeUnits(v, units, newUnits)
                  )
                })
                (adjustedTimeseries, newUnits)
              }
            }
            let md = metadata->Belt.Array.map(x => {...x, units: newUnits})
            (ts, md)
          }
        | false => (timeseries, metadata)
        }
      })
    (testIndex, adjustedDataByMetricName)
  })
}
