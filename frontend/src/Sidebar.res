open! Prelude
open Components

let linkForPull = (repoId, (pullNumber, _)) => {
  AppRouter.RepoPull({repoId: repoId, pullNumber: pullNumber})->AppRouter.path
}

let pullToString = ((pullNumber, branch)) =>
  switch branch {
  | Some(branch) => "#" ++ Belt.Int.toString(pullNumber) ++ " - " ++ branch
  | None => "#" ++ Belt.Int.toString(pullNumber)
  }

module GetRepoPulls = %graphql(`
query ($repoId: String!) {
  pullNumbers: benchmarks(distinct_on: [pull_number], where: {_and: [{repo_id: {_eq: $repoId}}, {pull_number: {_is_null: false}}]}, order_by: [{pull_number: desc}]) {
    pull_number
    branch
  }  
}
`)

module PullsMenu = {
  @react.component
  let make = (~repoId, ~selectedPull=?) => {
    let ({ReasonUrql.Hooks.response: response}, _) = {
      ReasonUrql.Hooks.useQuery(
        ~query=module(GetRepoPulls),
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
    | Data(data)
    | PartialData(data, _) =>
      let pulls =
        data.pullNumbers->Belt.Array.map(obj => (obj.pull_number |> Belt.Option.getExn, obj.branch))

      pulls
      ->Belt.Array.mapWithIndex((i, pull) => {
        let (pullNumber, _) = pull
        <Link
          sx=[Sx.pb.md]
          active={selectedPull->Belt.Option.mapWithDefault(false, selectedPullNumber =>
            selectedPullNumber == pullNumber
          )}
          key={string_of_int(i)}
          href={linkForPull(repoId, pull)}
          text={pullToString(pull)}
        />
      })
      ->Rx.array
    }
  }
}

@react.component
let make = (~repoIds, ~selectedRepoId=?, ~onSelectRepoId, ~selectedPull=?) => {
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
      <Icon sx=[Sx.unsafe("width", "36px"), Sx.mt.md] svg=Icon.ocaml />
      <Heading level=#h3 sx=[Sx.ml.lg, Sx.mt.lg] text="Benchmarks" />
    </Row>
    <Column>
      <Text sx=[Sx.mb.md] color=Sx.gray700 weight=#bold uppercase=true size=#sm>
        {Rx.text("Repositories")}
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
    <Column>
      <Text color=Sx.gray700 weight=#bold uppercase=true size=#sm>
        {Rx.text("Pull Requests")}
      </Text>
      {switch selectedRepoId {
      | Some(repoId) => <PullsMenu repoId ?selectedPull />
      | None => Rx.text("None")
      }}
    </Column>
  </Column>
}
