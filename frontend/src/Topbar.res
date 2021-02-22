open Components

@react.component
let make = (~children) => {
  <Flex
    alignY=#center
    sx=[Sx.w.full, Sx.borderB.xs, Sx.borderB.color(Sx.gray300), Sx.minH.xl3, Sx.p.lg]>
    <Row alignY=#center spacing=#between> {children} </Row>
  </Flex>
}
