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
query ($repoId: String!, $pullNumber: Int, $isMaster: Boolean!, $startDate: timestamp!, $endDate: timestamp!, $comparisonLimit: Int!) {
  benchmarks: benchmarks(where: {_and: [{pull_number: {_eq: $pullNumber}}, {pull_number: {_is_null: $isMaster}}, {repo_id: {_eq: $repoId}}, {run_at: {_gte: $startDate}}, {run_at: {_lt: $endDate}}]}) {
    ...BenchmarkMetrics
  }

  comparisonBenchmarks: benchmarks(where: {_and: [{pull_number: {_is_null: true}}, {repo_id: {_eq: $repoId}}, {run_at: {_gte: $startDate}}, {run_at: {_lt: $endDate}}]}, limit: $comparisonLimit) {
    ...BenchmarkMetrics
  }
}
`)

let makeGetBenchmarksVariables = (
  ~repoId,
  ~pullNumber=?,
  ~startDate,
  ~endDate,
): GetBenchmarks.t_variables => {
  let isMaster = Belt.Option.isNone(pullNumber)
  let comparisonLimit = isMaster ? 0 : 10
  {
    repoId: repoId,
    pullNumber: pullNumber,
    isMaster: isMaster,
    startDate: startDate,
    endDate: endDate,
    comparisonLimit: comparisonLimit,
  }
}

let getTestMetrics = (item: BenchmarkMetrics.t): BenchmarkTest.testMetrics => {
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

module BenchmarkView = {
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
      ->Belt.Map.String.reduce(acc, (acc, metricName, value) => {
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
  let make = (~repoId, ~pullNumber=?, ~startDate, ~endDate) => {
    let ({ReasonUrql.Hooks.response: response}, _) = {
      let startDate = Js.Date.toISOString(startDate)->Js.Json.string
      let endDate = Js.Date.toISOString(endDate)->Js.Json.string
      ReasonUrql.Hooks.useQuery(
        ~query=module(GetBenchmarks),
        makeGetBenchmarksVariables(~repoId, ~pullNumber?, ~startDate, ~endDate),
      )
    }

    switch response {
    | Empty => <div> {"Something went wrong!"->Rx.text} </div>
    | Error({networkError: Some(_)}) => <div> {"Network Error"->Rx.text} </div>
    | Error({networkError: None}) => <div> {"Unknown Error"->Rx.text} </div>
    | Fetching => Rx.text("Loading...")
    | Data(data)
    | PartialData(data, _) =>
      Js.log(data)
      let benchmarkDataByTestName = data.benchmarks->makeBenchmarkData
      let comparisonBenchmarkDataByTestName = data.comparisonBenchmarks->makeBenchmarkData

      let graphs = {
        benchmarkDataByTestName
        ->Belt.Map.String.mapWithKey((testName, dataByMetricName) => {
          let comparison = Belt.Map.String.getWithDefault(
            comparisonBenchmarkDataByTestName,
            testName,
            Belt.Map.String.empty,
          )
          <BenchmarkTest repoId pullNumber key={testName} testName dataByMetricName comparison />
        })
        ->Belt.Map.String.valuesToArray
      }

      <Column spacing=Sx.xl3>
        {graphs->Rx.array(~empty=<Message text="No data for selected interval." />)}
      </Column>
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

module RepoView = {
  @react.component
  let make = (~repoId=?, ~pullNumber=?) => {
    let ({ReasonUrql.Hooks.response: response}, _) = {
      ReasonUrql.Hooks.useQuery(~query=module(GetAllRepos), ())
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

      let breadcrumbs =
        <Row sx=[Sx.w.auto, Sx.text.noUnderline] alignY=#center>
          <Text weight=#semibold> {Rx.text("/")} </Text>
          {repoId->Rx.onSome(repoId => {
            let href = AppRouter.Repo({repoId: repoId})->AppRouter.path
            <Link href text="master" />
          })}
          {repoId->Rx.onSome(repoId => {
            pullNumber->Rx.onSome(pullNumber => {
              let href =
                AppRouter.RepoPull({repoId: repoId, pullNumber: pullNumber})->AppRouter.path
              <>
                <Text weight=#semibold> {Rx.text("/")} </Text>
                <Link href icon=Icon.branch text={string_of_int(pullNumber)} />
              </>
            })
          })}
        </Row>
      let githubLink =
        repoId->Rx.onSome(repoId =>
          <Link href={"https://github.com/" ++ repoId} sx=[Sx.ml.auto, Sx.mr.xl] icon=Icon.github />
        )

      <div className={Sx.make([Sx.container, Sx.d.flex])}>
        <Sidebar
          selectedRepoId=?repoId
          selectedPull=?pullNumber
          repoIds
          onSelectRepoId={repoId => AppRouter.Repo({repoId: repoId})->AppRouter.go}
        />
        <Column sx=[Sx.w.full, Sx.minW.zero]>
          <Topbar>
            {breadcrumbs}
            {githubLink}
            <Litepicker startDate endDate sx=[Sx.w.xl5] onSelect={onSelectDateRange} />
          </Topbar>
          <Block sx=[Sx.px.xl2, Sx.py.xl2, Sx.w.full, Sx.minW.zero]>
            {switch repoId {
            | Some(repoId) => <BenchmarkView repoId ?pullNumber startDate endDate />
            | None => Rx.text("No repository selected.")
            }}
          </Block>
        </Column>
      </div>
    }
  }
}
@react.component
let make = () => {
  let route = AppRouter.useRoute()

  switch route {
  | Error({reason}) => Rx.text("Router error: " ++ reason)
  | Ok(Main) => <RepoView />
  | Ok(Repo({repoId})) => <RepoView repoId />
  | Ok(RepoPull({repoId, pullNumber})) => <RepoView repoId pullNumber />
  }
}
