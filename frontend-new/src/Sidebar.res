open! Prelude
open Components

let linkForBranch = branch => {
  let name = DataHelpers.getBranchName(branch)
  "/#/branch/" ++ name
}

let branchesMenu = (~branches) => {
  <Column sx=[Sx.mt.lg]>
    <Text color=Sx.gray700 weight=#bold uppercase=true size=#md> {Rx.text("Pull Requests")} </Text>
    {branches
    ->Belt.Array.mapWithIndex((i, branch) =>
      <Link key={string_of_int(i)} href={linkForBranch(branch)} text=branch />
    )
    ->Rx.array}
  </Column>
}

@react.component
let make = (~url: ReasonReact.Router.url, ~branches, ~onSynchronizeToggle, ~synchronize) => {
  <div className={Sx.make(Styles.sidebarSx)}>
    <Row spacing=Sx.lg>
      <Block sx=[Sx.w.xl2, Sx.mt.xl]> <Icon svg=Icon.ocaml /> </Block> <Heading text="Benchmarks" />
    </Row>
    <Column stretch=true spacing=Sx.md>
      <Link active={url.hash == "/#"} href="#" icon=Icon.bolt text="mirage/index" />
    </Column>
    {branchesMenu(~branches)}
    <Field sx=[Sx.mb.md, Sx.self.end, Sx.mt.auto] label="Settings">
      <Row spacing=#between>
        {React.string("Synchronize graphs")} <Switch onToggle=onSynchronizeToggle on=synchronize />
      </Row>
    </Field>
  </div>
}
