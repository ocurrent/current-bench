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

module PullCompare = Belt.Id.MakeComparable({
  type t = (int, option<string>)
  let cmp = (a, b) => -compare(a, b)
})

let collectBenchmarksForRepo = (~repo_id, data: array<GetBenchmarks.t_benchmarks>): array<
  GetBenchmarks.t_benchmarks,
> => {
  data->Belt.Array.keep(item => item.repo_id == repo_id)
}

let collectPullsForRepo = (~repo_id, benchmarks: array<GetBenchmarks.t_benchmarks>): array<(
  int,
  option<string>,
)> => {
  benchmarks
  ->collectBenchmarksForRepo(~repo_id)
  ->Belt.Array.keepMap((item: GetBenchmarks.t_benchmarks) =>
    Belt.Option.flatMap(item.pull_number, pull_number => Some(pull_number, item.branch))
  )
  ->Belt.Set.fromArray(~id=module(PullCompare))
  ->Belt.Set.toArray
}

let collectRepoIds = (benchmarks: array<GetBenchmarks.t_benchmarks>): array<string> => {
  benchmarks
  ->Belt.Array.map(item => item.repo_id)
  ->Belt.Set.String.fromArray
  ->Belt.Set.String.toArray
}

let collectBenchmarksForPull = (~repo_id, ~pull, benchmarks) =>
  benchmarks
  ->collectBenchmarksForRepo(~repo_id)
  ->Belt.Array.keep((item: GetBenchmarks.t_benchmarks) => {
    item.pull_number == Some(pull)
  })

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

let getLatestMasterIndex = (~testName, benchmarks) => {
  BeltHelpers.Array.findIndexRev(benchmarks, (item: GetBenchmarks.t_benchmarks) => {
    item.pull_number == None && item.test_name == testName
  })
}

module BenchmarkResults = {
  @react.component
  let make = (~benchmarks: array<GetBenchmarks.t_benchmarks>, ~synchronize, ~repo_id) => {
    let data = benchmarks->Belt.Array.map(getTestMetrics)
    let selectionByTestName =
      data->Belt.Array.reduceWithIndex(Belt.Map.String.empty, BenchmarkTest.groupByTestName)

    let comparisonMetricsByTestName = {
      Belt.Map.String.mapWithKey(selectionByTestName, (testName, _) => {
        // TODO: Use the index load the data from master and add an annotation.
        switch getLatestMasterIndex(~testName, benchmarks) {
        | Some(idx) => Some(benchmarks[idx]->getTestMetrics)
        | None => None
        }
      })
    }

    let graphs = {
      selectionByTestName
      ->Belt.Map.String.mapWithKey((testName, testSelection) => {
        let comparisonMetrics = Belt.Map.String.getExn(comparisonMetricsByTestName, testName)
        <BenchmarkTest
          ?comparisonMetrics synchronize key={testName} data testName testSelection repo_id
        />
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

module Content = {
  @react.component
  let make = (
    ~pulls,
    ~selectedRepoId,
    ~repo_ids,
    ~benchmarks,
    ~startDate,
    ~endDate,
    ~onSelectDateRange,
    ~synchronize,
    ~onSynchronizeToggle,
    ~selectedPull=?,
  ) => {
    <div className={Sx.make([Sx.container, Sx.d.flex, Sx.flex.wrap])}>
      <Sidebar
        pulls
        selectedRepoId
        ?selectedPull
        repo_ids
        onSelectRepoId={selectedRepId => ReasonReact.Router.push("#/" ++ selectedRepoId)}
        synchronize
        onSynchronizeToggle
      />
      <div className={Sx.make(Styles.topbarSx)}>
        <Row alignY=#center spacing=#between>
          <Link href={"https://github.com/" ++ selectedRepoId} sx=[Sx.mr.xl] icon=Icon.github />
          <Text sx=[Sx.text.bold]>
            {Rx.text(
              Belt.Option.mapWithDefault(selectedPull, "master", pull =>
                "#" ++ string_of_int(pull)
              ),
            )}
          </Text>
          <Litepicker startDate endDate sx=[Sx.w.xl5] onSelect={onSelectDateRange} />
        </Row>
      </div>
      <div className={Sx.make(Styles.mainSx)}>
        <BenchmarkResults synchronize benchmarks repo_id=selectedRepoId />
      </div>
    </div>
  }
}

@react.component
let make = () => {
  let url = ReasonReact.Router.useUrl()

  let ((startDate, endDate), setDateRange) = React.useState(getDefaultDateRange)

  let onSelectDateRange = (d1, d2) => setDateRange(_ => (d1, d2))

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
    let repo_ids = collectRepoIds(data.benchmarks)

    switch String.split_on_char('/', url.hash) {
    | list{""} =>
      switch Belt.Array.get(repo_ids, 0) {
      | Some(firstRepo) => {
          // If no repository is selected, this redirects to the first one.
          ReasonReact.Router.replace("#/" ++ firstRepo)
          React.null
        }
      | None => <div> {"No data were found..."->Rx.string} </div>
      }
    | list{"", orgName, repoName, ...rest} => {
        let selectedRepoId =
          repo_ids->Belt.Array.getBy(repo_id => repo_id == orgName ++ "/" ++ repoName)
        switch selectedRepoId {
        | None => <div> {"This repo does not exist!"->Rx.string} </div>
        | Some(selectedRepoId) =>
          let pulls = collectPullsForRepo(~repo_id=selectedRepoId, benchmarks)
          switch rest {
          | list{"pull", pullNumberStr} =>
            switch Belt.Int.fromString(pullNumberStr) {
            | None =>
              <div> {("Pull request must be an integer. Got: " ++ pullNumberStr)->Rx.string} </div>
            | Some(selectedPull) =>
              if pulls->Belt.Array.some(((pullNr, _)) => pullNr == selectedPull) {
                let benchmarksForPull = collectBenchmarksForPull(
                  ~repo_id=selectedRepoId,
                  ~pull=selectedPull,
                  benchmarks,
                )
                <Content
                  pulls
                  selectedRepoId
                  repo_ids
                  benchmarks=benchmarksForPull
                  selectedPull
                  startDate
                  endDate
                  onSelectDateRange
                  synchronize
                  onSynchronizeToggle
                />
              } else {
                <div> {"This pull request does not exist!"->Rx.string} </div>
              }
            }
          | _ =>
            let benchmarksForRepo = collectBenchmarksForRepo(~repo_id=selectedRepoId, benchmarks)
            let benchmarksForMaster = Belt.Array.keep(benchmarksForRepo, (
              item: GetBenchmarks.t_benchmarks,
            ) => {
              // pullNumber is assumed to be None only for master
              Belt.Option.isNone(item.pull_number)
            })
            <Content
              pulls
              selectedRepoId
              repo_ids
              benchmarks=benchmarksForMaster
              startDate
              endDate
              onSelectDateRange
              synchronize
              onSynchronizeToggle
            />
          }
        }
      }
    | _ => <div> {("Unknown route: " ++ url.hash)->Rx.string} </div>
    }
  }
}
