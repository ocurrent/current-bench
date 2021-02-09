%%raw(`import './App.css';`)

open! Prelude
open JsHelpers
open Components

module GetBenchmarks = %graphql(`
query ($startDate: timestamp!, $endDate: timestamp!) {
  benchmarks(where: {_and: [{run_at: {_gte: $startDate}}, {run_at: {_lt: $endDate}}]}) {
      repo_id
      test_name
      metrics
      commit
      branch
      pull_number
      run_at
    }
  }
`)

let comparePulls = ((pn1, _b1), (pn2, _b2)) => {
  -compare(pn1, pn2)
}

let collectPulls = (data: array<GetBenchmarks.t_benchmarks>): array<(int, option<string>)> => {
  let data = Belt.List.fromArray(data)
  let data = Belt.List.keepMap(data, (item: GetBenchmarks.t_benchmarks) =>
    Belt.Option.flatMap(item.pull_number, pull_number => Some(pull_number, item.branch))
  )
  let data = List.sort_uniq(comparePulls, data)
  Belt.List.toArray(data)
}

let decodeRunAt = runAt => runAt->Js.Json.decodeString->Belt.Option.map(Js.Date.fromString)

let decodeMetrics = metrics =>
  metrics
  ->Belt.Option.getExn
  ->Js.Json.decodeObject
  ->Belt.Option.getExn
  ->jsDictToMap
  ->Belt.Map.String.map(v => BenchmarkTest.decodeMetricValue(v))

let getLatestMasterIndex = (~testName, benchmarks) => {
  BeltHelpers.Array.findIndexRev(benchmarks, (item: GetBenchmarks.t_benchmarks) => {
    item.pull_number == None && item.test_name == testName
  })
}

module BenchmarkView = {
  @react.component
  let make = (
    ~benchmarkDataByTestName: BenchmarkData.byTestName,
    ~comparisonBenchmarkDataByTestName=Belt.Map.String.empty,
  ) => {
    let graphs = {
      benchmarkDataByTestName
      ->Belt.Map.String.mapWithKey((testName, dataByMetricName) => {
        let comparison = Belt.Map.String.getWithDefault(
          comparisonBenchmarkDataByTestName,
          testName,
          Belt.Map.String.empty,
        )
        <BenchmarkTest key={testName} testName dataByMetricName comparison />
      })
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
    (Js.Date.fromFloat(ts1), Js.Date.fromFloat(ts2))
  }
}

@react.component
let make = () => {
  let url = ReasonReact.Router.useUrl()

  let ((startDate, endDate), setDateRange) = React.useState(getDefaultDateRange)

  // Fetch benchmarks data
  let ({ReasonUrql.Hooks.response: response}, _) = {
    let startDate = Js.Date.toISOString(startDate)->Js.Json.string
    let endDate = Js.Date.toISOString(endDate)->Js.Json.string
    ReasonUrql.Hooks.useQuery(
      ~query=module(GetBenchmarks),
      {
        startDate: startDate,
        endDate: endDate,
      },
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
    let benchmarks: array<GetBenchmarks.t_benchmarks> = data.benchmarks
    let pulls = collectPulls(benchmarks)

    let benchmarkData = benchmarks->Belt.Array.reduce(BenchmarkData.empty, (acc, item) => {
      item.metrics
      ->decodeMetrics
      ->Belt.Map.String.reduce(acc, (acc, metricName, value) => {
        BenchmarkData.add(
          acc,
          ~pullNumber=item.pull_number,
          ~testName=item.test_name,
          ~metricName,
          ~runAt=item.run_at->decodeRunAt->Belt.Option.getExn,
          ~commit=item.commit,
          ~value,
        )
      })
    })

    let (main, mainTitle) = {
      switch String.split_on_char('/', url.hash) {
      | list{""} =>
        let benchmarkDataByTestName = BenchmarkData.forPullNumber(benchmarkData, None)
        (<BenchmarkView benchmarkDataByTestName />, "master")
      | list{"", "pull", pullNumberStr} =>
        switch Belt.Int.fromString(pullNumberStr) {
        | Some(pullNumber) =>
          let benchmarkDataByTestName = BenchmarkData.forPullNumber(benchmarkData, Some(pullNumber))
          let comparisonBenchmarkDataByTestName = BenchmarkData.forPullNumber(benchmarkData, None)
          (
            <BenchmarkView benchmarkDataByTestName comparisonBenchmarkDataByTestName />,
            "#" ++ pullNumberStr,
          )
        | None => (<h1> {Rx.string("Invalid pull number: " ++ pullNumberStr)} </h1>, "Not found")
        }
      | _ => (<h1> {Rx.string("Unknown route: " ++ url.hash)} </h1>, "Not found")
      }
    }

    <div className={Sx.make([Sx.container, Sx.d.flex, Sx.flex.wrap])}>
      <Sidebar url onSynchronizeToggle synchronize pulls />
      <div className={Sx.make(Styles.topbarSx)}>
        <Row alignY=#center spacing=#between>
          <Link href="https://github.com/mirage/index" sx=[Sx.mr.xl] icon=Icon.github />
          <Text sx=[Sx.text.bold]> {Rx.text(mainTitle)} </Text>
          <Litepicker
            startDate endDate onSelect={(d1, d2) => setDateRange(_ => (d1, d2))} sx=[Sx.w.xl5]
          />
        </Row>
      </div>
      <div className={Sx.make(Styles.mainSx)}> {main} </div>
    </div>
  }
}
