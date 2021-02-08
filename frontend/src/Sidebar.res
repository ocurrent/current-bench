open! Prelude
open Components

let linkForPull = (repo, (pull_number, _)) => {
  "#/" ++ repo ++ "/pull/" ++ Belt.Int.toString(pull_number)
}

let pullToString = ((pull_number, branch)) =>
  switch branch {
  | Some(branch) => "#" ++ Belt.Int.toString(pull_number) ++ " - " ++ branch
  | None => "#" ++ Belt.Int.toString(pull_number)
  }

module PullsMenu = {
  @react.component
  let make = (~pulls, ~repo, ~selectedPull=?) => {
    <Column>
      <Text color=Sx.gray700 weight=#bold uppercase=true size=#md>
        {Rx.text("Pull Requests")}
      </Text>
      {pulls
      ->Belt.Array.mapWithIndex((i, pull) => {
        let (pull_number, _) = pull
        <Link
          active={selectedPull->Belt.Option.mapWithDefault(false, selectedPullNumber =>
            selectedPullNumber == pull_number
          )}
          key={string_of_int(i)}
          href={linkForPull(repo, pull)}
          text={pullToString(pull)}
        />
      })
      ->Rx.array}
    </Column>
  }
}

@react.component
let make = (
  ~pulls,
  ~selectedRepo,
  ~repos,
  ~onSelectRepo,
  ~onSynchronizeToggle,
  ~synchronize,
  ~selectedPull=?,
) => {
  <Column spacing=Sx.xl2 sx=Styles.sidebarSx>
    <select
      name="repos"
      value={selectedRepo}
      onChange={e => ReactEvent.Form.target(e)["value"]->onSelectRepo}>
      {repos
      ->Belt.Array.mapWithIndex((i, repo) =>
        <option key={string_of_int(i)} value={repo}> {Rx.string(repo)} </option>
      )
      ->Rx.array}
    </select>
    <PullsMenu repo=selectedRepo pulls ?selectedPull />
  </Column>
}
