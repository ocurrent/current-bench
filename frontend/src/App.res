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

let getTestMetrics = (item: GetBenchmarks.t_benchmarks): BenchmarkTest.testMetrics => {
  {
    BenchmarkTest.name: item.test_name,
    metrics: item.metrics
    ->Belt.Option.getExn
    ->Js.Json.decodeObject
    ->Belt.Option.getExn
    ->jsDictToMap
    ->Belt.Map.String.map(v => BenchmarkTest.decodeMetricValue(v)),
    commit: item.commit,
  }
}

let getLatestMasterEntry = (~testName, benchmarks) => {
  BeltHelpers.arrayFindRev(benchmarks, (item: GetBenchmarks.t_benchmarks) => {
    item.pull_number == None && item.test_name == testName
  })
}

module BenchmarkResults = {
  @react.component
  let make = (~benchmarks: array<GetBenchmarks.t_benchmarks>, ~pullNumber=?, ~synchronize) => {
    let data = Belt.Array.keep(benchmarks, (item: GetBenchmarks.t_benchmarks) => {
      // pullNumber is assumed to be None only for master
      item.pull_number == pullNumber
    })
    let data = data->Belt.Array.map(getTestMetrics)
    let selectionByTestName =
      data->Belt.Array.reduceWithIndex(Belt.Map.String.empty, BenchmarkTest.groupByTestName)

    let comparisonMetricsByTestName = {
      Belt.Map.String.mapWithKey(selectionByTestName, (testName, _) =>
        getLatestMasterEntry(~testName, benchmarks)->Belt.Option.map(getTestMetrics)
      )
    }

    let graphs = {
      selectionByTestName
      ->Belt.Map.String.mapWithKey((testName, testSelection) => {
        let comparisonMetrics = Belt.Map.String.getExn(comparisonMetricsByTestName, testName)
        <BenchmarkTest ?comparisonMetrics synchronize key={testName} data testName testSelection />
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

    let (main, mainTitle) = {
      switch String.split_on_char('/', url.hash) {
      | list{""} => (<BenchmarkResults synchronize benchmarks />, "master")
      | list{"", "pull", pullNumberStr} =>
        switch Belt.Int.fromString(pullNumberStr) {
        | Some(pullNumber) => (
            <BenchmarkResults synchronize pullNumber benchmarks />,
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
