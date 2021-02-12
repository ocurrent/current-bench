open! Prelude
open Components

let linkForPull = (repo_id, (pull_number, _)) => {
  "#/" ++ repo_id ++ "/pull/" ++ Belt.Int.toString(pull_number)
}

let pullToString = ((pull_number, branch)) =>
  switch branch {
  | Some(branch) => "#" ++ Belt.Int.toString(pull_number) ++ " - " ++ branch
  | None => "#" ++ Belt.Int.toString(pull_number)
  }

module PullsMenu = {
  @react.component
  let make = (~pulls, ~repo_id, ~selectedPull=?) => {
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
          href={linkForPull(repo_id, pull)}
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
  ~selectedRepoId,
  ~repo_ids,
  ~onSelectRepoId,
  ~onSynchronizeToggle,
  ~synchronize,
  ~selectedPull=?,
) => {
  <Column spacing=Sx.xl2 sx=Styles.sidebarSx>
    <Components.Select
      name="repositories"
      value={selectedRepoId}
      placeholder="Select a repository"
      onChange={e => ReactEvent.Form.target(e)["value"]->onSelectRepoId}>
      {repo_ids
      ->Belt.Array.mapWithIndex((i, repo_id) =>
        <option key={string_of_int(i)} value={repo_id}> {Rx.string(repo_id)} </option>
      )
      ->Rx.array}
    </Components.Select>
    <PullsMenu repo_id=selectedRepoId pulls ?selectedPull />
  </Column>
}
