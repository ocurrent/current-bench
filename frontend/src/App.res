%%raw(`import './App.css';`)

open! Prelude
open Components
open BenchmarkQueryHelpers

module GetAllRepos = %graphql(`
query {
  allRepoIds: benchmark_metadata(distinct_on: [repo_id]) {
    repo_id
  }
}
`)

let makeGetBenchmarksVariables = (
  ~repoId,
  ~branch=?,
  ~pullNumber=?,
  ~pullBase=?,
  ~worker,
  ~benchmarkName=?,
  ~startDate,
  ~endDate,
): GetBenchmarks.t_variables => {
  open BenchmarkDataHelpers
  let isMaster = Belt.Option.isNone(pullNumber)
  let (worker, dockerImage) = switch worker {
  | None => (None, None)
  | Some((worker, dockerImage)) => (Some(worker), Some(dockerImage))
  }
  let comparisonLimit = isMaster ? 0 : 50
  {
    repoId,
    branch,
    pullNumber,
    pullBase,
    isMaster,
    worker,
    dockerImage,
    benchmarkName: Js.Global.decodeURIComponent(Belt.Option.getWithDefault(benchmarkName, defaultBenchmarkName)),
    startDate,
    endDate,
    comparisonLimit,
  }
}

module Benchmark = {
  let decodeRunAt = runAt => runAt->Js.Json.decodeString->Belt.Option.map(Js.Date.fromString)

  let yojson_of_result = (result: BenchmarkMetrics.t) => {
    let metrics = DataHelpers.yojson_of_json(result.metrics->Belt.Option.getExn)
    #Assoc(list{
      ("version", #Int(result.version)),
      (
        "results",
        #List(list{#Assoc(list{("name", #String(result.test_name)), ("metrics", metrics)})}),
      ),
    })
  }

  let decode = (result: BenchmarkMetrics.t) => {
    let metrics = yojson_of_result(result)
    let metrics = Schema.of_json(metrics)
    let run_at = result.run_at->decodeRunAt->Belt.Option.getExn
    (result.commit, result.run_job_id, run_at, result.test_index, metrics)
  }

  let tryDecode = result => {
    try {
      Some(decode(result))
    } catch {
    | _ => None
    }
  }

  let toLineGraph = (value: Schema.value) => {
    switch value {
    | Float(x) => LineGraph.DataRow.single(x)
    | Floats(xs) => LineGraph.DataRow.many(Array.of_list(xs))
    | Assoc(xs) => LineGraph.DataRow.map(Array.of_list(xs))
    }
  }

  let makeBenchmarkData = (benchmarks: array<BenchmarkMetrics.t>) => {
    benchmarks
    ->Belt.Array.keepMap(tryDecode)
    ->Belt.Array.reduce(BenchmarkData.empty, (
      acc,
      (commit, run_job_id, run_at, test_index, item),
    ) => {
      List.fold_left((acc, result: Schema.result) => {
        List.fold_left((acc, metric: Schema.metric) => {
          BenchmarkData.add(
            acc,
            ~testName=result.test_name,
            ~testIndex=test_index,
            ~metricName=metric.name,
            ~runAt=run_at,
            ~commit,
            ~value=toLineGraph(metric.value),
            ~units=metric.units,
            ~description=metric.description,
            ~trend=metric.trend,
            ~lines=metric.lines,
            ~run_job_id,
          )
        }, acc, result.metrics)
      }, acc, item.results)
    })
  }

  @react.component
  let make = React.memo((~repoId, ~pullNumber, ~data: GetBenchmarks.t, ~lastCommit) => {
    let benchmarkDataByTestName = React.useMemo2(
      () =>
        data.benchmarks
        ->makeBenchmarkData
        ->AdjustMetricUnit.adjust
        ->BenchmarkDataHelpers.fillMissingValues,
      (data.benchmarks, makeBenchmarkData),
    )

    let comparisonBenchmarkDataByTestName = React.useMemo3(
      () =>
        data.comparisonBenchmarks
        ->Belt.Array.reverse
        ->makeBenchmarkData
        ->AdjustMetricUnit.adjustComparisonData(benchmarkDataByTestName)
        ->BenchmarkDataHelpers.fillMissingValues
        ->BenchmarkDataHelpers.addMissingComparisonMetrics(benchmarkDataByTestName),
      (data.benchmarks, data.comparisonBenchmarks, makeBenchmarkData),
    )

    let graphsData = React.useMemo1(() => {
      benchmarkDataByTestName
      ->Belt.Map.String.mapWithKey((testName, (testIndex, dataByMetricName)) => {
        let (_, comparison) = Belt.Map.String.getWithDefault(
          comparisonBenchmarkDataByTestName,
          testName,
          (0, Belt.Map.String.empty),
        )
        (dataByMetricName, comparison, testName, testIndex)
      })
      ->Belt.Map.String.valuesToArray
    }, [benchmarkDataByTestName])

    // Mapping of all overlayed graph labels to a color;
    // Used to assign the same color to a label across different metrics
    let labelColorMapping = React.useMemo1(() => {
      let suffixes =
        benchmarkDataByTestName
        ->Belt.Map.String.valuesToArray
        ->Belt.Array.map(((_, dataByMetricName)) =>
          dataByMetricName
          ->Belt.Map.String.keysToArray
          ->Belt.Array.map(x => Js.String.split("/", x))
          ->Belt.Array.keep(x => x->Belt.Array.length > 1)
          ->Belt.Array.map(x => x[1])
        )
        ->Belt.Array.concatMany
        ->Belt.Set.String.fromArray
        ->Belt.Set.String.toArray

      let colors = LineGraph.category20colors
      let n = colors->Belt.Array.length
      Belt.Array.reduceWithIndex(suffixes, Belt.Map.String.empty, (map, label, idx) => {
        let color = colors->Belt.Array.getExn(mod(idx, n))
        Belt.Map.String.set(map, label, color)
      })
    }, [benchmarkDataByTestName])

    <Column spacing=Sx.xl>
      {graphsData
      ->Belt.List.fromArray
      ->Belt.List.sort(((_, _, _, idx1), (_, _, _, idx2)) => idx1 - idx2)
      ->Belt.List.toArray
      ->Belt.Array.map(((dataByMetricName, comparison, testName, _)) =>
        <BenchmarkTest
          repoId
          pullNumber
          key={testName}
          testName
          dataByMetricName
          comparison
          lastCommit
          labelColorMapping
        />
      )
      ->Rx.array(~empty=<Message text="No data for selected interval." />)}
    </Column>
  })
}

module BenchmarkView = {
  @react.component
  let make = (~repoId, ~branch=?, ~pullNumber=?, ~pullBase=?, ~worker, ~benchmarkName=?, ~startDate, ~endDate) => {
    let ({ReScriptUrql.Hooks.response: response}, _) = {
      let startDate = Js.Date.toISOString(startDate)->Js.Json.string
      let endDate = Js.Date.toISOString(endDate)->Js.Json.string
      ReScriptUrql.Hooks.useQuery(
        ~query=module(GetBenchmarks),
        makeGetBenchmarksVariables(
          ~repoId,
          ~branch?,
          ~pullNumber?,
          ~pullBase?,
          ~worker,
          ~benchmarkName?,
          ~startDate,
          ~endDate,
        ),
      )
    }

    let (lastCommit, setLastCommit) = React.useState(() => None)

    switch response {
    | Empty => <div> {"Something went wrong!"->Rx.text} </div>
    | Error({networkError: Some(_)}) => <div> {"Network Error"->Rx.text} </div>
    | Error({networkError: None}) => <div> {"Unknown Error"->Rx.text} </div>
    | Fetching => Rx.text("Loading...")
    | Data(data)
    | PartialData(data, _) =>
      <Block sx=[Sx.px.xl2, Sx.py.xl2, Sx.w.full, Sx.minW.zero]>
        <CommitInfo repoId worker ?branch ?pullNumber benchmarks=data setLastCommit />
        <Benchmark repoId pullNumber data lastCommit />
      </Block>
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
    let version: string = %raw(`process.env.VITE_CURRENT_BENCH_VERSION`)
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
        <br />
        {Rx.text("Report issues at ")}
        <a target="_blank" href="https://github.com/ocaml/infrastructure">
          {Rx.text("https://github.com/ocaml/infrastructure")}
        </a>
        {Rx.text(".")}
        <br />
        <Text sx=[Sx.text.xs]> {`Version: ${version}`} </Text>
      </center>
    </Column>
  }
}

let makeOnSelectRepoId = (worker, repoId) =>
  AppRouter.Repo({repoId: repoId, benchmarkName: None, worker: worker})->AppRouter.go

module ErrorView = {
  @react.component
  let make = (~msg, ~repoIds=[], ~onSelectRepoId=makeOnSelectRepoId(None)) => {
    <>
      <Sidebar repoIds onSelectRepoId worker=None setWorker={_ => ()} />
      <Column alignX=#center sx=[Sx.mt.xl]>
        <Heading level=#h1 align=#center text=`Application error ⚠` />
        <Row alignX=#center sx=[Sx.text.color(Sx.gray900)]> {Rx.text(msg)} </Row>
        <br />
        <p>
          {Rx.text("Report an issue at ")}
          <a target="_blank" href="https://github.com/ocurrent/current-bench">
            {Rx.text("https://github.com/ocurrent/current-bench")}
          </a>
        </p>
      </Column>
    </>
  }
}

module RepoView = {
  @react.component
  let make = (~repoId=?, ~branch=?, ~pullNumber=?, ~pullBase=?, ~benchmarkName=?, ~worker) => {
    let ({ReScriptUrql.Hooks.response: response}, _) = {
      ReScriptUrql.Hooks.useQuery(~query=module(GetAllRepos), ())
    }

    let ((startDate, endDate), setDateRange) = React.useState(getDefaultDateRange)
    let onSelectDateRange = (startDate, endDate) => setDateRange(_ => (startDate, endDate))

    let setWorker = worker => {
      switch (repoId, pullNumber, pullBase) {
      | (Some(repoId), Some(pullNumber), Some(pullBase)) =>
        AppRouter.RepoPull({
          repoId: repoId,
          pullNumber: pullNumber,
          pullBase: pullBase,
          benchmarkName: benchmarkName,
          worker: worker,
        })->AppRouter.go
      | (Some(repoId), _, _) => AppRouter.Repo({repoId, benchmarkName, worker})->AppRouter.go
      | _ => ()
      }
    }

    switch response {
    | Empty => <div> {"Something went wrong!"->Rx.text} </div>
    | Error({networkError: Some(_)}) => <div> {"Network Error"->Rx.text} </div>
    | Error({networkError: None}) => <div> {"Unknown Error"->Rx.text} </div>
    | Fetching => Rx.text("Loading...")
    | Data(data)
    | PartialData(data, _) =>
      let repoIds = data.allRepoIds->Belt.Array.map(obj => obj.repo_id)
      let onSelectRepoId = makeOnSelectRepoId(worker)
      let sidebar: React.element = {
        <Sidebar
          repoIds
          worker
          setWorker
          selectedBranch=?branch
          selectedRepoId=?repoId
          selectedPull=?pullNumber
          selectedBenchmarkName=?benchmarkName
          onSelectRepoId
        />
      }

      <div className={Sx.make([Sx.container, Sx.d.flex])}>
        {switch repoId {
        | None => <>
            sidebar
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
          <ErrorView msg={"No such repository: " ++ repoId} repoIds onSelectRepoId />
        | Some(repoId) =>
          let pullBase = Belt.Option.getWithDefault(pullBase, "")
          let breadcrumbs =
            <Row sx=[Sx.w.auto, Sx.text.noUnderline] alignY=#center>
              {pullNumber->Rx.onSome(pullNumber => {
                let href = AppRouter.RepoPull({
                  repoId: repoId,
                  pullNumber: pullNumber,
                  pullBase: pullBase,
                  benchmarkName: None,
                  worker: worker,
                })->AppRouter.path
                <>
                <Text weight=#semibold> "/" </Text>
                {
                  let href = AppRouter.RepoBranch({
                    repoId: repoId,
                    branch: pullBase,
                    benchmarkName: None,
                    worker: worker,
                  })->AppRouter.path
                  <Link href text={pullBase} />
                }
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
                    worker: worker,
                  })
                | Some(pullNumber) =>
                  AppRouter.RepoPull({
                    repoId: repoId,
                    pullNumber: pullNumber,
                    pullBase: pullBase,
                    benchmarkName: Some(benchmarkName),
                    worker: worker,
                  })
                }->AppRouter.path
                <> <Text weight=#semibold> "/" </Text> <Link href text={benchmarkName} /> </>
              })}
            </Row>
          let githubLink =
            <a
              href={"https://github.com/" ++ repoId}
              className={Sx.make([Sx.ml.auto, Sx.mr.xl, Sx.text.color(Sx.black)])}
              target="_blank">
              {Icon.github}
            </a>
          <>
            sidebar
            <Column sx=[Sx.w.full, Sx.minW.zero]>
              <Topbar>
                {breadcrumbs}
                {githubLink}
                <Litepicker startDate endDate sx=[Sx.w.xl5] onSelect={onSelectDateRange} />
              </Topbar>
              <BenchmarkView repoId worker ?branch ?pullNumber pullBase ?benchmarkName startDate endDate />
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
  | Error({reason}) =>
    <div className={Sx.make([Sx.container, Sx.d.flex])}> <ErrorView msg={reason} /> </div>
  | Ok(Main) => <RepoView worker={None} />
  | Ok(Repo({repoId, benchmarkName, worker})) => <RepoView repoId ?benchmarkName worker />
  | Ok(RepoPull({repoId, pullNumber, pullBase, benchmarkName, worker})) =>
    <RepoView repoId pullNumber pullBase ?benchmarkName worker />
  | Ok(RepoBranch({repoId, branch, benchmarkName, worker})) =>
    <RepoView repoId branch ?benchmarkName worker />
  }
}
