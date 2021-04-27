%%raw(`import './App.css';`)

open! Prelude
open JsHelpers
open Components

module GetAllRepos = %graphql(`
query {
  allRepoIds: benchmarks(distinct_on: [repo_id]) {
    repo_id
  }
}
`)

module BenchmarkMetrics = %graphql(`
fragment BenchmarkMetrics on benchmarks {
  run_at
  commit
  test_name
  metrics
}
`)

module GetBenchmarks = %graphql(`
query ($repoId: String!, $pullNumber: Int, $isMaster: Boolean!, $benchmarkName: String, $isDefaultBenchmark: Boolean!, $startDate: timestamp!, $endDate: timestamp!, $comparisonLimit: Int!) {
  benchmarks: benchmarks(where: {_and: [{pull_number: {_eq: $pullNumber}}, {pull_number: {_is_null: $isMaster}}, {repo_id: {_eq: $repoId}}, {benchmark_name: {_is_null: $isDefaultBenchmark, _eq: $benchmarkName}}, {run_at: {_gte: $startDate}}, {run_at: {_lt: $endDate}}]}) {
    ...BenchmarkMetrics
  }
  comparisonBenchmarks: benchmarks(where: {_and: [{pull_number: {_is_null: true}}, {repo_id: {_eq: $repoId}}, {benchmark_name: {_is_null: $isDefaultBenchmark, _eq: $benchmarkName}}, {run_at: {_gte: $startDate}}, {run_at: {_lt: $endDate}}]}, limit: $comparisonLimit, order_by: [{run_at: desc}]) {
    ...BenchmarkMetrics
  }
}
`)

let makeGetBenchmarksVariables = (
  ~repoId,
  ~pullNumber=?,
  ~benchmarkName=?,
  ~startDate,
  ~endDate,
): GetBenchmarks.t_variables => {
  let isMaster = Belt.Option.isNone(pullNumber)
  let isDefaultBenchmark = Belt.Option.isNone(benchmarkName)
  let comparisonLimit = isMaster ? 0 : 50
  {
    repoId: repoId,
    pullNumber: pullNumber,
    isMaster: isMaster,
    isDefaultBenchmark: isDefaultBenchmark,
    benchmarkName: benchmarkName,
    startDate: startDate,
    endDate: endDate,
    comparisonLimit: comparisonLimit,
  }
}

module Benchmark = {
  let decodeRunAt = runAt => runAt->Js.Json.decodeString->Belt.Option.map(Js.Date.fromString)

  let decodeMetrics = metrics =>
    metrics
    ->Belt.Option.getExn
    ->Js.Json.decodeObject
    ->Belt.Option.getExn
    ->jsDictToMap
    ->Belt.Map.String.map(v => BenchmarkTest.decodeMetricValue(v))

  let makeBenchmarkData = (benchmarks: array<BenchmarkMetrics.t>) => {
    benchmarks->Belt.Array.reduce(BenchmarkData.empty, (acc, item) => {
      item.metrics
      ->decodeMetrics
      ->Belt.Map.String.reduce(acc, (acc, metricName, value: LineGraph.DataRow.value) => {
        BenchmarkData.add(
          acc,
          ~testName=item.test_name,
          ~metricName,
          ~runAt=item.run_at->decodeRunAt->Belt.Option.getExn,
          ~commit=item.commit,
          ~value,
        )
      })
    })
  }
  @react.component
  let make = React.memo((~repoId, ~pullNumber, ~data: GetBenchmarks.t) => {
    let benchmarkDataByTestName = React.useMemo2(() => {
      data.benchmarks->makeBenchmarkData
    }, (data.benchmarks, makeBenchmarkData))
    let comparisonBenchmarkDataByTestName = React.useMemo2(
      () => data.comparisonBenchmarks->Belt.Array.reverse->makeBenchmarkData,
      (data.comparisonBenchmarks, makeBenchmarkData),
    )

    let graphsData = React.useMemo1(() => {
      benchmarkDataByTestName
      ->Belt.Map.String.mapWithKey((testName, dataByMetricName) => {
        let comparison = Belt.Map.String.getWithDefault(
          comparisonBenchmarkDataByTestName,
          testName,
          Belt.Map.String.empty,
        )
        (dataByMetricName, comparison, testName)
      })
      ->Belt.Map.String.valuesToArray
    }, [benchmarkDataByTestName])

    <Column spacing=Sx.xl>
      {graphsData
      ->Belt.Array.map(((dataByMetricName, comparison, testName)) =>
        <BenchmarkTest repoId pullNumber key={testName} testName dataByMetricName comparison />
      )
      ->Rx.array(~empty=<Message text="No data for selected interval." />)}
    </Column>
  })
}

module BenchmarkView = {
  @react.component
  let make = (~repoId, ~pullNumber=?, ~benchmarkName=?, ~startDate, ~endDate) => {
    let ({ReScriptUrql.Hooks.response: response}, _) = {
      let startDate = Js.Date.toISOString(startDate)->Js.Json.string
      let endDate = Js.Date.toISOString(endDate)->Js.Json.string
      ReScriptUrql.Hooks.useQuery(
        ~query=module(GetBenchmarks),
        makeGetBenchmarksVariables(~repoId, ~pullNumber?, ~benchmarkName?, ~startDate, ~endDate),
      )
    }

    switch response {
    | Empty => <div> {"Something went wrong!"->Rx.text} </div>
    | Error({networkError: Some(_)}) => <div> {"Network Error"->Rx.text} </div>
    | Error({networkError: None}) => <div> {"Unknown Error"->Rx.text} </div>
    | Fetching => Rx.text("Loading...")
    | Data(data)
    | PartialData(data, _) =>
      <Benchmark repoId pullNumber data />
    }
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

module Welcome = {
  @react.component
  let make = () => {
    <Column alignX=#center sx=[Sx.mt.xl]>
      <Heading level=#h1 align=#center text=`hello world 👋` />
      <center>
        {Rx.text("Measure and track benchmark results for your OCaml projects.")}
        <br />
        {Rx.text("Learn more at ")}
        <a target="_blank" href="https://github.com/ocurrent/current-bench">
          {Rx.text("https://github.com/ocurrent/current-bench")}
        </a>
        {Rx.text(".")}
      </center>
    </Column>
  }
}

module ErrorView = {
  @react.component
  let make = (~msg) => {
    <Column alignX=#center sx=[Sx.mt.xl]>
      <Heading level=#h1 align=#center text=`Application error` />
      <Row alignX=#center sx=[Sx.text.color(Sx.gray900)]> {Rx.text(msg)} </Row>
      <br />
      {Rx.text("Learn more at ")}
      <a target="_blank" href="https://github.com/ocurrent/current-bench">
        {Rx.text("https://github.com/ocurrent/current-bench")}
      </a>
    </Column>
  }
}

module RepoView = {
  @react.component
  let make = (~repoId=?, ~pullNumber=?, ~benchmarkName=?) => {
    let ({ReScriptUrql.Hooks.response: response}, _) = {
      ReScriptUrql.Hooks.useQuery(~query=module(GetAllRepos), ())
    }

    let ((startDate, endDate), setDateRange) = React.useState(getDefaultDateRange)
    let onSelectDateRange = (startDate, endDate) => setDateRange(_ => (startDate, endDate))

    switch response {
    | Empty => <div> {"Something went wrong!"->Rx.text} </div>
    | Error({networkError: Some(_)}) => <div> {"Network Error"->Rx.text} </div>
    | Error({networkError: None}) => <div> {"Unknown Error"->Rx.text} </div>
    | Fetching => Rx.text("Loading...")
    | Data(data)
    | PartialData(data, _) =>
      let repoIds = data.allRepoIds->Belt.Array.map(obj => obj.repo_id)

      let sidebar =
        <Sidebar
          selectedRepoId=?repoId
          selectedPull=?pullNumber
          selectedBenchmarkName=?benchmarkName
          repoIds
          onSelectRepoId={repoId =>
            AppRouter.Repo({repoId: repoId, benchmarkName: None})->AppRouter.go}
        />

      <div className={Sx.make([Sx.container, Sx.d.flex])}>
        {switch repoId {
        | None => <>
            {sidebar}
            <Column sx=[Sx.w.full, Sx.minW.zero]>
              <Topbar>
                <Litepicker
                  startDate=?None
                  endDate=?None
                  sx=[Sx.w.xl5, Sx.ml.auto]
                  onSelect={onSelectDateRange}
                />
              </Topbar>
              <Welcome />
            </Column>
          </>
        | Some(repoId) if !(repoIds->BeltHelpers.Array.contains(repoId)) =>
          <ErrorView msg={"No such repository: " ++ repoId} />
        | Some(repoId) =>
          let breadcrumbs =
            <Row sx=[Sx.w.auto, Sx.text.noUnderline] alignY=#center>
              <Text weight=#semibold> "/" </Text>
              {
                let href = AppRouter.Repo({repoId: repoId, benchmarkName: None})->AppRouter.path
                <Link href text="master" />
              }
              {pullNumber->Rx.onSome(pullNumber => {
                let href = AppRouter.RepoPull({
                  repoId: repoId,
                  pullNumber: pullNumber,
                  benchmarkName: None,
                })->AppRouter.path
                <>
                  <Text weight=#semibold> "/" </Text>
                  <Link href icon=Icon.branch text={string_of_int(pullNumber)} />
                </>
              })}
              {benchmarkName->Rx.onSome(benchmarkName => {
                let href = switch pullNumber {
                | None =>
                  AppRouter.Repo({
                    repoId: repoId,
                    benchmarkName: Some(benchmarkName),
                  })
                | Some(pullNumber) =>
                  AppRouter.RepoPull({
                    repoId: repoId,
                    pullNumber: pullNumber,
                    benchmarkName: Some(benchmarkName),
                  })
                }->AppRouter.path
                <> <Text weight=#semibold> "/" </Text> <Link href text={benchmarkName} /> </>
              })}
            </Row>
          let githubLink =
            <Link
              href={"https://github.com/" ++ repoId} sx=[Sx.ml.auto, Sx.mr.xl] icon=Icon.github
            />

          <>
            {sidebar}
            <Column sx=[Sx.w.full, Sx.minW.zero]>
              <Topbar>
                {breadcrumbs}
                {githubLink}
                <Litepicker startDate endDate sx=[Sx.w.xl5] onSelect={onSelectDateRange} />
              </Topbar>
              <Block sx=[Sx.px.xl2, Sx.py.xl2, Sx.w.full, Sx.minW.zero]>
                <CommitInfo repoId ?pullNumber />
                <BenchmarkView repoId ?pullNumber ?benchmarkName startDate endDate />
              </Block>
            </Column>
          </>
        }}
      </div>
    }
  }
}
@react.component
let make = () => {
  let route = AppRouter.useRoute()

  switch route {
  | Error({reason}) => <ErrorView msg={reason} />
  | Ok(Main) => <RepoView />
  | Ok(Repo({repoId, benchmarkName})) => <RepoView repoId ?benchmarkName />
  | Ok(RepoPull({repoId, pullNumber, benchmarkName})) =>
    <RepoView repoId pullNumber ?benchmarkName />
  }
}
