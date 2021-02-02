open! Prelude
open Components

let linkForPull = ((pull_number, _)) => {
  "/#/pull/" ++ Belt.Int.toString(pull_number)
}

let pullToString = ((pull_number, branch)) =>
  switch branch {
  | Some(branch) => "#" ++ Belt.Int.toString(pull_number) ++ " - " ++ branch
  | None => "#" ++ Belt.Int.toString(pull_number)
  }

let pullsMenu = (~pulls) => {
  <Column>
    <Text color=Sx.gray700 weight=#bold uppercase=true size=#md> {Rx.text("Pull Requests")} </Text>
    {pulls
    ->Belt.Array.mapWithIndex((i, pull) =>
      <Link key={string_of_int(i)} href={linkForPull(pull)} text={pullToString(pull)} />
    )
    ->Rx.array}
  </Column>
}

@react.component
let make = (~url: ReasonReact.Router.url, ~pulls, ~onSynchronizeToggle, ~synchronize) => {
  let repo_name = "mirage/index"
  <Column spacing=Sx.xl2 sx=Styles.sidebarSx>
    <a className={Sx.make([Sx.text.noUnderline, Sx.text.color(Sx.black)])} href="/#">
      <Row spacing=Sx.lg>
        <Icon sx=[Sx.unsafe("width", "48px"), Sx.mt.md] svg=Icon.ocaml />
        <Column spacing=#px(-6)>
          <Heading level=#h4 sx=[Sx.m.zero] text=repo_name />
          <Text size=#sm color=Sx.gray800> {Rx.text("Benchmarks")} </Text>
        </Column>
      </Row>
    </a>
    {pullsMenu(~pulls)}
  </Column>
}
