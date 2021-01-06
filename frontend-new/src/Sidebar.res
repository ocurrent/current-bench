open! Prelude
open Components

let pullsMenu = (~pulls) => {
  <Column sx=[Sx.mt.lg]>
    <Text color=Sx.gray700 weight=#bold uppercase=true size=#md> {Rx.text("Pull Requests")} </Text>
    <Link href="#/pull/" text="#264" />
    <Link href="#/pull/" text="#263" />
    <Link href="#/pull/" text="#262" />
  </Column>
}

@react.component
let make = (~url: ReasonReact.Router.url, ~pulls, ~onSynchronizeToggle, ~synchronize) => {
  <div className={Sx.make(Styles.sidebarSx)}>
    <Row spacing=Sx.lg>
      <Block sx=[Sx.w.xl2, Sx.mt.xl]> <Icon svg=Icon.ocaml /> </Block> <Heading text="Benchmarks" />
    </Row>
    <Column stretch=true spacing=Sx.md>
      <Link active={url.hash == "/#"} href="#" icon=Icon.bolt text="mirage/index" />
    </Column>
    {pullsMenu(~pulls)}
    <Field sx=[Sx.mb.md, Sx.self.end, Sx.mt.auto] label="Settings">
      <Row spacing=#between>
        {React.string("Synchronize graphs")} <Switch onToggle=onSynchronizeToggle on=synchronize />
      </Row>
    </Field>
  </div>
}
