open! Prelude
open Components

let pullToString = ((pullNumber, prTitle, branch)) =>
  switch branch {
  | Some(branch) => "#" ++ Belt.Int.toString(pullNumber) ++ " - " ++ branch
  | None => "#" ++ Belt.Int.toString(pullNumber) ++ " " ++ prTitle
  }

module SidebarMenuData = %graphql(`
query ($repoId: String!) {
  pullsMenuData: benchmark_metadata(distinct_on: [pull_number], where: {_and: [{repo_id: {_eq: $repoId}}, {pull_number: {_is_null: false}}]}, order_by: [{pull_number: desc}]) {
    pull_number
    is_open_pr
    branch
    pr_title
  }
  benchmarksMenuData: benchmarks(distinct_on: [benchmark_name], where: {repo_id: {_eq: $repoId}}, order_by: [{benchmark_name: asc_nulls_first}]) {
    benchmark_name
  }
  branchesMenuData: benchmark_metadata(distinct_on: [branch], where: {_and: [{repo_id: {_eq: $repoId}}, {branch: {_is_null: false}}]}, order_by: [{branch: asc_nulls_first}]) {
    branch
  }
}
`)

module PullsList = {
  @react.component
  let make = (~repoId, ~pullNumberInfos, ~selectedPull=?, ~selectedBenchmarkName=?, ~worker) => {
    pullNumberInfos
    ->Belt.Array.mapWithIndex((i, pullNumberInfo) => {
      let (pullNumber, prTitle) = pullNumberInfo

      <Row key={string_of_int(i)}>
        <a
          href={AppHelpers.pullUrl(~repoId, ~pull=string_of_int(pullNumber))}
          className={Sx.make([Sx.ml.xs, Sx.mr.md, Sx.pt.md, Sx.text.color(Sx.gray400)])}
          target="_blank">
          {Icon.github}
        </a>
        <Link
          sx=[
            Sx.pb.md,
            Sx.text.overflowEllipsis,
            Sx.text.noWrapWhiteSpace,
            Sx.text.blockDisplay,
            Sx.text.hiddenOverflow,
          ]
          active={selectedPull === Some(pullNumber)}
          key={string_of_int(i)}
          href={AppRouter.RepoPull({
            repoId: repoId,
            pullNumber: pullNumber,
            benchmarkName: selectedBenchmarkName,
            worker: worker,
          })->AppRouter.path}
          text={pullToString((pullNumber, prTitle, None))}
        />
      </Row>
    })
    ->Rx.array(~empty="None"->Rx.string)
  }
}

module PullsMenu = {
  @react.component
  let make = (
    ~repoId,
    ~pullsMenuData: array<SidebarMenuData.t_pullsMenuData>,
    ~selectedPull=?,
    ~selectedBenchmarkName=?,
    ~worker,
  ) => {
    let openPullNumberInfos = pullsMenuData->Belt.Array.keepMap(obj =>
      switch obj.pull_number {
      | Some(pullNumber) if obj.is_open_pr =>
        Some(pullNumber, Belt.Option.getWithDefault(obj.pr_title, ""))
      | _ => None
      }
    )

    let closedPullNumberInfos = pullsMenuData->Belt.Array.keepMap(obj =>
      switch obj.pull_number {
      | Some(pullNumber) if !obj.is_open_pr =>
        Some(pullNumber, Belt.Option.getWithDefault(obj.pr_title, ""))
      | _ => None
      }
    )

    <Column>
      <Text color=Sx.gray700 weight=#bold uppercase=true size=#sm> "Pull Requests" </Text>
      <PullsList
        repoId pullNumberInfos={openPullNumberInfos} ?selectedPull ?selectedBenchmarkName worker
      />
      {closedPullNumberInfos->Belt.Array.length > 0
        ? <details>
            <summary>
              <Text color=Sx.gray700 weight=#bold uppercase=true size=#xs>
                "Closed Pull Requests"
              </Text>
            </summary>
            <PullsList
              repoId
              pullNumberInfos={closedPullNumberInfos}
              ?selectedPull
              ?selectedBenchmarkName
              worker
            />
          </details>
        : Rx.null}
    </Column>
  }
}

module BenchmarksMenu = {
  @react.component
  let make = (
    ~repoId,
    ~benchmarksMenuData: array<SidebarMenuData.t_benchmarksMenuData>,
    ~selectedPull=?,
    ~selectedBenchmarkName=?,
    ~worker,
  ) => {
    benchmarksMenuData
    ->Belt.Array.mapWithIndex((i, {benchmark_name: benchmarkName}) => {
      let benchmarkRoute = switch selectedPull {
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
          benchmarkName: Some(benchmarkName),
          worker: worker,
        })
      }

      <Link
        sx=[Sx.pb.md, Sx.text.capital]
        active={selectedBenchmarkName == Some(benchmarkName)}
        key={string_of_int(i)}
        href={benchmarkRoute->AppRouter.path}
        text={benchmarkName}
      />
    })
    ->Rx.array(~empty="None"->Rx.string)
  }
}

let defaultBranch = "main"
let validDefaults = Belt.Set.String.fromArray(["main", "trunk", "master"])

module BranchesMenu = {
  @react.component
  let make = (
    ~repoId,
    ~branchesMenuData: array<SidebarMenuData.t_branchesMenuData>,
    ~selectedBranch=?,
    ~selectedBenchmarkName=?,
    ~selectedPull=?,
    ~worker,
  ) => {
    let branchNames = branchesMenuData->Belt.Array.keepMap(obj => obj.branch)

    React.useEffect3(() => {
      if (
        Belt.Option.isNone(selectedPull) &&
        branchNames->Belt.Array.getBy(name => Some(name) == selectedBranch) == None
      ) {
        switch branchNames->Belt.Array.getBy(name => Belt.Set.String.has(validDefaults, name)) {
        | Some(branch) =>
          AppRouter.RepoBranch({
            repoId,
            branch,
            benchmarkName: selectedBenchmarkName,
            worker,
          })->AppRouter.go
        | _ => ()
        }
      }
      None
    }, (selectedBranch, branchesMenuData, selectedPull))

    let branches =
      branchesMenuData
      ->Belt.Array.mapWithIndex((i, {branch}) => {
        let branchRoute = switch branch {
        | None =>
          AppRouter.Repo({
            repoId,
            benchmarkName: selectedBenchmarkName,
            worker,
          })
        | Some(branch) =>
          AppRouter.RepoBranch({
            repoId,
            branch,
            benchmarkName: selectedBenchmarkName,
            worker,
          })
        }
        <Link
          sx=[Sx.pb.md, Sx.text.capital]
          active={selectedBranch == branch}
          key={string_of_int(i)}
          href={branchRoute->AppRouter.path}
          text={Belt.Option.getWithDefault(branch, defaultBranch)}
        />
      })
      ->Rx.array(~empty="None"->Rx.string)
    switch Belt.Array.length(branchesMenuData) {
    | 0 | 1 => Rx.null
    | _ =>
      <Column>
        <Text color=Sx.gray700 weight=#bold uppercase=true size=#sm> "Branches" </Text>
        {branches}
      </Column>
    }
  }
}

module SidebarMenu = {
  @react.component
  let make = (~repoId, ~selectedBranch=?, ~selectedPull=?, ~selectedBenchmarkName=?, ~worker) => {
    let ({ReScriptUrql.Hooks.response: response}, _) = {
      ReScriptUrql.Hooks.useQuery(
        ~query=module(SidebarMenuData),
        {
          repoId: repoId,
        },
      )
    }

    switch response {
    | Empty => <div> {"Something went wrong!"->Rx.text} </div>
    | Error({networkError: Some(_)}) => <div> {"Network Error"->Rx.text} </div>
    | Error({networkError: None}) => <div> {"Unknown Error"->Rx.text} </div>
    | Fetching => Rx.text("Loading...")
    | Data({benchmarksMenuData, pullsMenuData, branchesMenuData})
    | PartialData({benchmarksMenuData, pullsMenuData, branchesMenuData}, _) =>
      <>
        {switch Belt.Array.some(benchmarksMenuData, bm => {
          bm.benchmark_name !== BenchmarkDataHelpers.defaultBenchmarkName
        }) {
        | true =>
          <Column>
            <Text color=Sx.gray700 weight=#bold uppercase=true size=#sm> "Benchmarks" </Text>
            <BenchmarksMenu repoId benchmarksMenuData ?selectedPull ?selectedBenchmarkName worker />
          </Column>
        | false => Rx.null
        }}
        <BranchesMenu
          repoId branchesMenuData ?selectedPull ?selectedBranch ?selectedBenchmarkName worker
        />
        <PullsMenu repoId pullsMenuData ?selectedPull ?selectedBenchmarkName worker />
      </>
    }
  }
}

type worker = {worker: string, docker_image: string}

module WorkersSelect = {
  @react.component
  let make = (~worker, ~setWorker, ~workers: array<worker>): React.element => {
    let idx_opt = {
      workers->Belt.Array.getIndexBy(w => worker == Some((w.worker, w.docker_image)))
    }

    React.useEffect2(() => {
      switch idx_opt {
      | None if workers->Belt.Array.length > 0 =>
        let first = workers[0]
        setWorker(Some((first.worker, first.docker_image)))
      | _ => ()
      }
      None
    }, (idx_opt, workers))

    let idx = idx_opt->Belt.Option.getWithDefault(0)

    switch Belt.Array.length(workers) {
    | 0 | 1 => <> </>
    | _ =>
      <Column>
        <Text color=Sx.gray700 weight=#bold uppercase=true size=#sm> "Environment" </Text>
        <Select
          name="worker-image"
          value={string_of_int(idx)}
          placeholder="Select a worker"
          onChange={e => {
            let idx = int_of_string(ReactEvent.Form.target(e)["value"])
            let w = workers[idx]
            setWorker(Some((w.worker, w.docker_image)))
          }}>
          {workers
          ->Belt.Array.mapWithIndex((i, run) => {
            let idx = string_of_int(i)
            <option key={idx} value={idx}>
              {(run.docker_image ++ " (" ++ run.worker ++ ")")->Rx.text}
            </option>
          })
          ->Rx.array}
        </Select>
      </Column>
    }
  }
}

module Workers = {
  @react.component
  let make = (~worker, ~setWorker, ~repoId, ~selectedPull): React.element => {
    let isMain = Belt.Option.isNone(selectedPull)
    let ({ReScriptUrql.Hooks.response: response}, _) = {
      ReScriptUrql.Hooks.useQuery(
        ~query=module(BenchmarkQueryHelpers.GetWorkers),
        {repoId: repoId, pullNumber: selectedPull, isMain: isMain},
      )
    }

    switch response {
    | Empty => <div> {"Something went wrong!"->Rx.text} </div>
    | Error({networkError: Some(_)}) => <div> {"Network Error"->Rx.text} </div>
    | Error({networkError: None}) => <div> {"Unknown Error"->Rx.text} </div>
    | Fetching => Rx.text("Loading...")
    | Data(data)
    | PartialData(data, _) =>
      // Data fetched from the Postgres View through GraphQL makes NOT NULL columns nullable
      let workers = data.workers->Belt.Array.map(({worker, docker_image}) => {
        worker: worker->Belt.Option.getWithDefault(""),
        docker_image: docker_image->Belt.Option.getWithDefault(""),
      })
      <WorkersSelect worker setWorker workers />
    }
  }
}

@react.component
let make = (
  ~repoIds,
  ~worker,
  ~setWorker,
  ~selectedBranch=?,
  ~selectedRepoId=?,
  ~selectedPull=?,
  ~selectedBenchmarkName=?,
  ~onSelectRepoId,
): React.element => {
  let menu = switch selectedRepoId {
  | None => Rx.null
  | Some(repoId) =>
    <>
      <Workers worker setWorker repoId selectedPull />
      <SidebarMenu repoId ?selectedBranch ?selectedPull ?selectedBenchmarkName worker />
    </>
  }

  <Column
    spacing=Sx.xl
    sx=[
      Sx.t.zero,
      Sx.h.screen,
      Sx.sticky,
      Sx.w.xl5,
      Sx.borderR.xs,
      Sx.borderR.color(Sx.gray300),
      Sx.overflowY.scroll,
      Sx.overflowX.hidden,
      Sx.bg.color(Sx.white),
      Sx.px.xl,
      Sx.py.lg,
    ]>
    <Row spacing=Sx.lg alignY=#center>
      <Link
        href="/"
        icon={<Icon sx=[Sx.unsafe("width", "36px"), Sx.mr.lg] svg=Icon.ocaml />}
        sx=[Sx.text.bold, Sx.text.xl, Sx.hover([Sx.text.color(Sx.gray900)])]
        text="Benchmarks"
      />
    </Row>
    {switch repoIds->Belt.Array.length {
    | 0 => Rx.null
    | _ =>
      <Column>
        <Text sx=[Sx.mb.md] color=Sx.gray700 weight=#bold uppercase=true size=#sm>
          "Repositories"
        </Text>
        <Select
          name="repositories"
          value=?selectedRepoId
          placeholder="Select a repository"
          onChange={e => ReactEvent.Form.target(e)["value"]->onSelectRepoId}>
          {repoIds
          ->Belt.Array.mapWithIndex((i, repoId) =>
            <option key={string_of_int(i)} value={repoId}> {Rx.string(repoId)} </option>
          )
          ->Rx.array}
        </Select>
      </Column>
    }}
    menu
  </Column>
}
