%%raw(`import './App.css';`)

open! Prelude
open JsHelpers
open JsonHelpers
open Components

module GetBenchmarks = %graphql(`
query ($startDate: float8!, $endDate: float8!) {
  benchmarks(where: {_and: [{timestamp: {_gte: $startDate}}, {timestamp: {_lt: $endDate}}]}) {
      repositories
      json_data
      commits
      branch
      timestamp
    }
  }
`)

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

module BenchmarkTest = {
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

  let getTestMetrics = (item: GetBenchmarks.t_benchmarks): array<testMetrics> => {
    item.json_data
    ->Belt.Option.getExn
    ->jsonFieldExn("result", Js.Json.Object)
    ->Js.Dict.get("results")
    ->Belt.Option.getExn
    ->Js.Json.decodeArray
    ->Belt.Option.getExn
    ->Belt.Array.map(result => {
      {
        name: jsonFieldExn(result, "name", Js.Json.String),
        metrics: result
        ->jsonFieldExn("metrics", Js.Json.Object)
        ->jsDictToMap
        ->Belt.Map.String.map(v => decodeMetricValue(v)),
        commit: item.commits,
      }
    })
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
  let make = (~dataframe, ~testName, ~testSelection, ~synchronize=true) => {
    let dataByMetrics = dataframe->groupDataByMetric(testSelection)
    let graphRefs = ref(list{})
    let onGraphRender = graph => graphRefs := Belt.List.add(graphRefs.contents, graph)

    // Compute xTicks, i.e., commits.
    let xTicks = testSelection->Belt.Set.Int.reduce(Belt.Map.Int.empty, (acc, idx) => {
      let item: testMetrics = Belt.Array.getExn(dataframe, idx)
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
        data
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
}

let collectBranches = (data: array<GetBenchmarks.t_benchmarks>) => {
  data
  ->Belt.Array.map((item: GetBenchmarks.t_benchmarks) =>
    item.branch->Belt.Option.getWithDefault("Unknown")
  )
  ->Belt.Set.String.fromArray
  ->Belt.Set.String.toArray
}

module BenchmarkResults = {
  @react.component
  let make = (~benchmarks, ~synchronize) => {
    let dataframe =
      benchmarks
      ->Belt.Array.sliceToEnd(-20)
      ->Belt.Array.map(BenchmarkTest.getTestMetrics)
      ->Belt.Array.concatMany
    let selectionByTestName =
      dataframe->Belt.Array.reduceWithIndex(Belt.Map.String.empty, BenchmarkTest.groupByTestName)

    let graphs = {
      selectionByTestName
      ->Belt.Map.String.mapWithKey((testName, testSelection) =>
        <BenchmarkTest synchronize key={testName} dataframe testName testSelection />
      )
      ->Belt.Map.String.valuesToArray
    }

    <Column spacing=Sx.xl3>
      {graphs->Rx.array(~empty=<Message text="No data for selected interval." />)}
    </Column>
  }
}

let getDefaultDateRange = {
  let hourMs = 3600.0 *. 1000.
  let dayMs = hourMs *. 24.
  () => {
    let ts2 = Js.Date.now()
    let ts1 = ts2 -. 90. *. dayMs
    Js.log([ts1, ts2])
    (Js.Date.fromFloat(ts1), Js.Date.fromFloat(ts2))
  }
}

@react.component
let make = () => {
  let url = ReasonReact.Router.useUrl()

  let ((startDate, endDate), setDateRange) = React.useState(getDefaultDateRange)

  // Fetch benchmarks data
  let ({ReasonUrql.Hooks.response: response}, _) = {
    let startDate = (Js.Date.getTime(startDate) /. 1000.0)->Js.Json.number
    let endDate = (Js.Date.getTime(endDate) /. 1000.0)->Js.Json.number
    ReasonUrql.Hooks.useQuery(
      ~query=module(GetBenchmarks),
      {startDate: startDate, endDate: endDate},
    )
  }

  let (synchronize, setSynchronize) = React.useState(() => false)
  let onSynchronizeToggle = () => {
    setSynchronize(v => !v)
  }

  switch response {
  | Error(e) =>
    switch e.networkError {
    | Some(_e) => <div> {"Network Error"->React.string} </div>
    | None => <div> {"Unknown Error"->React.string} </div>
    }
  | Empty => <div> {"Something went wrong!"->React.string} </div>
  | Fetching => Rx.string("Loading...")
  | Data(data)
  | PartialData(data, _) =>
    let benchmarks = data.benchmarks
    let branches = collectBranches(benchmarks)

    <div className={Sx.make([Sx.container, Sx.d.flex, Sx.flex.wrap])}>
      <Sidebar url onSynchronizeToggle synchronize branches />
      <div className={Sx.make(Styles.topbarSx)}>
        <Row alignY=#center spacing=#between>
          <Link href="https://github.com/mirage/index" sx=[Sx.mr.xl] icon=Icon.github />
          <Text sx=[Sx.text.bold]> {Rx.text("Results")} </Text>
          <Litepicker
            startDate endDate onSelect={(d1, d2) => setDateRange(_ => (d1, d2))} sx=[Sx.w.xl5]
          />
        </Row>
      </div>
      <div className={Sx.make(Styles.mainSx)}>
        {switch url.hash {
        | "" => <BenchmarkResults synchronize benchmarks />
        | _ => <h1> {Rx.string("Unknown route")} </h1>
        }}
      </div>
    </div>
  }
}
