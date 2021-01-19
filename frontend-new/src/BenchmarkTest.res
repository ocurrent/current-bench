open! Prelude
open Components

type testMetrics = {
  name: string,
  commit: string,
  metrics: Belt.Map.String.t<float>,
}

let commitUrl = commit => `https://github.com/mirage/index/commit/${commit}`
let goToCommitLink = commit => {
  let openUrl: string => unit = %raw(`function (url) { window.open(url, "_blank") }`)
  openUrl(commitUrl(commit))
}

let groupByTestName = (acc, item: testMetrics, idx) => {
  let go = vOpt => {
    let idxs = switch vOpt {
    | Some(idxs) => idxs
    | None => Belt.Set.Int.empty
    }
    Some(Belt.Set.Int.add(idxs, idx))
  }
  Belt.Map.String.update(acc, item.name, go)
}

let decodeMetricValue = json => {
  switch Js.Json.classify(json) {
  | JSONNumber(n) => n
  | JSONArray([]) => 0.0
  | JSONArray(ns) =>
    Belt.Array.get(ns, 0)->Belt.Option.getExn->Js.Json.decodeNumber->Belt.Option.getExn
  | _ => invalid_arg("Invalid metric value: " ++ Js.Json.stringify(json))
  }
}

let collectMetricsByKey = (
  ~metricName,
  items: array<testMetrics>,
  selection: Belt.Set.Int.t,
): array<array<float>> => {
  let data = Belt.Array.makeUninitializedUnsafe(Belt.Set.Int.size(selection))
  Belt.Set.Int.reduce(selection, 0, (i, idx) => {
    let item: testMetrics = Belt.Array.getExn(items, idx)
    let metricWithIndex = [idx->float_of_int, item.metrics->Belt.Map.String.getExn(metricName)]
    Belt.Array.setExn(data, i, metricWithIndex)
    i + 1
  })->ignore
  data
}

let groupDataByMetric = (items: array<testMetrics>, selection: Belt.Set.Int.t): Belt.Map.String.t<
  array<array<float>>,
> => {
  open Belt

  let addMetricValue = (selectionIdx, acc, metricName, metricValue) => {
    let row = [selectionIdx->float_of_int, metricValue]
    BeltHelpers.MapString.addToArray(acc, metricName, row)
  }

  let groupByMetric = (acc, selectionIdx) => {
    let testMetrics = Array.getExn(items, selectionIdx)
    testMetrics.metrics->Map.String.reduce(acc, addMetricValue(selectionIdx))
  }

  selection->Set.Int.reduce(Map.String.empty, groupByMetric)
}

let renderMetricOverviewRow = (~xTicks, metricName, data) => {
  if Belt.Array.length(data) == 0 {
    React.null
  } else {
    let second_to_last_value = try Belt.Array.getExn(
      data,
      Belt.Array.length(data) - 2,
    )->Belt.Array.getExn(1) catch {
    | _ => 0.0
    }

    let last_value = Belt.Array.getExn(data, Belt.Array.length(data) - 1)->Belt.Array.getExn(1)
    let idx = Belt.Array.getExn(data, Belt.Array.length(data) - 1)->Belt.Array.getExn(0)
    let commit = Belt.Map.Int.getExn(xTicks, idx->Belt.Float.toInt)

    let delta = {
      let n = if second_to_last_value == 0.0 {
        0.0
      } else {
        let n = (second_to_last_value -. last_value) /. second_to_last_value *. 100.
        last_value < second_to_last_value ? -.n : abs_float(n)
      }
      if n > 0.0 {
        "+" ++ n->Js.Float.toFixedWithPrecision(~digits=2) ++ "%"
      } else {
        n->Js.Float.toFixedWithPrecision(~digits=2) ++ "%"
      }
    }
    <Table.Row key=metricName>
      <Table.Col> {Rx.text(metricName)} </Table.Col>
      <Table.Col> <Link target="_blank" href={commitUrl(commit)} text=commit /> </Table.Col>
      <Table.Col> {Rx.text(last_value->Js.Float.toFixedWithPrecision(~digits=2))} </Table.Col>
      <Table.Col sx=[Sx.text.right]> {Rx.text(delta)} </Table.Col>
    </Table.Row>
  }
}

@react.component
let make = (~data, ~testName, ~testSelection, ~synchronize=true) => {
  let dataByMetrics = data->groupDataByMetric(testSelection)
  let graphRefs = ref(list{})
  let onGraphRender = graph => graphRefs := Belt.List.add(graphRefs.contents, graph)

  // Compute xTicks, i.e., commits.
  let xTicks = testSelection->Belt.Set.Int.reduce(Belt.Map.Int.empty, (acc, idx) => {
    let item: testMetrics = Belt.Array.getExn(data, idx)
    let tick = item.commit
    let tick = String.length(tick) > 7 ? String.sub(tick, 0, 7) : tick
    Belt.Map.Int.set(acc, idx, tick)
  })

  React.useEffect1(() => {
    if synchronize {
      LineGraph.synchronize(graphRefs.contents->Belt.List.toArray)
    }
    None
  }, [synchronize])

  let metric_table = {
    <Table>
      <thead>
        <tr className={Sx.make([Sx.h.xl2])}>
          <th> {React.string("Metric")} </th>
          <th> {React.string("Last Commit")} </th>
          <th> {React.string("Last Value")} </th>
          <th> {React.string("Delta")} </th>
        </tr>
      </thead>
      <tbody>
        {dataByMetrics
        ->Belt.Map.String.mapWithKey(renderMetricOverviewRow(~xTicks))
        ->Belt.Map.String.valuesToArray
        ->Rx.array}
      </tbody>
    </Table>
  }

  let metric_graphs = dataByMetrics
  ->Belt.Map.String.mapWithKey((metricName, data) => {
    <LineGraph
      onXLabelClick=goToCommitLink
      onRender=onGraphRender
      key=metricName
      title=metricName
      xTicks
      data={data->Belt.Array.sliceToEnd(-20)}
      labels=["idx", "value"]
    />
  })
  ->Belt.Map.String.valuesToArray
  ->Rx.array

  <details className={Sx.make([Sx.w.full])} open_=true>
    <summary className={Sx.make([Sx.pointer])}>
      <Text sx=[Sx.text.xl3, Sx.text.bold]> {Rx.text(testName)} </Text>
    </summary>
    <Column sx=[Sx.mt.xl]> metric_table <Flex wrap=true> metric_graphs </Flex> </Column>
  </details>
}
