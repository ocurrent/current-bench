open! Prelude
open Components

let pullToString = ((pullNumber, branch)) =>
  switch branch {
  | Some(branch) => "#" ++ Belt.Int.toString(pullNumber) ++ " - " ++ branch
  | None => "#" ++ Belt.Int.toString(pullNumber)
  }

module SidebarMenuData = %graphql(`
query ($repoId: String!) {
  pullsMenuData: benchmarks(distinct_on: [pull_number], where: {_and: [{repo_id: {_eq: $repoId}}, {pull_number: {_is_null: false}}]}, order_by: [{pull_number: desc}]) {
    pull_number
    branch
  }  
  benchmarksMenuData: benchmarks(distinct_on: [benchmark_name], where: {repo_id: {_eq: $repoId}}, order_by: [{benchmark_name: asc_nulls_first}]) {
    benchmark_name
  }
}
`)

module PullsMenu = {
  @react.component
  let make = (
    ~repoId,
    ~pullsMenuData: array<SidebarMenuData.t_pullsMenuData>,
    ~selectedPull=?,
    ~selectedBenchmarkName=?,
  ) => {
    let pullNumbers = pullsMenuData->Belt.Array.keepMap(obj => obj.pull_number)

    pullNumbers
    ->Belt.Array.mapWithIndex((i, pullNumber) => {
      <Link
        sx=[Sx.pb.md]
        active={selectedPull === Some(pullNumber)}
        key={string_of_int(i)}
        href={AppRouter.RepoPull({
          repoId: repoId,
          pullNumber: pullNumber,
          benchmarkName: selectedBenchmarkName,
        })->AppRouter.path}
        text={pullToString((pullNumber, None))}
      />
    })
    ->Rx.array(~empty="None"->Rx.string)
  }
}

module BenchmarksMenu = {
  @react.component
  let make = (
    ~repoId,
    ~benchmarksMenuData: array<SidebarMenuData.t_benchmarksMenuData>,
    ~selectedPull=?,
    ~selectedBenchmarkName=?,
  ) => {
    benchmarksMenuData
    ->Belt.Array.mapWithIndex((i, {benchmark_name: benchmarkName}) => {
      let benchmarkRoute = switch selectedPull {
      | None =>
        AppRouter.Repo({
          repoId: repoId,
          benchmarkName: benchmarkName,
        })
      | Some(pullNumber) =>
        AppRouter.RepoPull({
          repoId: repoId,
          pullNumber: pullNumber,
          benchmarkName: benchmarkName,
        })
      }

      <Link
        sx=[Sx.pb.md, Sx.text.capital]
        active={selectedBenchmarkName == benchmarkName}
        key={string_of_int(i)}
        href={benchmarkRoute->AppRouter.path}
        text={benchmarkName->Belt.Option.getWithDefault("main")}
      />
    })
    ->Rx.array(~empty="None"->Rx.string)
  }
}

module SidebarMenu = {
  @react.component
  let make = (~repoId, ~selectedPull=?, ~selectedBenchmarkName=?) => {
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
    | Data({benchmarksMenuData, pullsMenuData})
    | PartialData({benchmarksMenuData, pullsMenuData}, _) => <>
        <Column>
          <Text color=Sx.gray700 weight=#bold uppercase=true size=#sm> "Benchmarks" </Text>
          <BenchmarksMenu repoId benchmarksMenuData ?selectedPull ?selectedBenchmarkName />
        </Column>
        <Column>
          <Text color=Sx.gray700 weight=#bold uppercase=true size=#sm> "Pull Requests" </Text>
          <PullsMenu repoId pullsMenuData ?selectedPull ?selectedBenchmarkName />
        </Column>
      </>
    }
  }
}

@react.component
let make = (
  ~repoIds,
  ~selectedRepoId=?,
  ~onSelectRepoId,
  ~selectedPull=?,
  ~selectedBenchmarkName=?,
) => {
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
    {switch selectedRepoId {
    | Some(repoId) => <SidebarMenu repoId ?selectedPull ?selectedBenchmarkName />
    | None => Rx.null
    }}
  </Column>
}
