let fetchOptions = ReasonUrql.Client.FetchOpts(
  Fetch.RequestInit.make(
    ~headers=Fetch.HeadersInit.make({"X-Hasura-Admin-Secret": "zbNoMU69kxiw"}),
    (),
  ),
)

let client = ReasonUrql.Client.make(
  ~url="http://autumn.ocamllabs.io:8080/v1/graphql",
  ~fetchOptions,
  (),
)

ReactDOMRe.renderToElementWithId(
  <ReasonUrql.Context.Provider value=client> <App /> </ReasonUrql.Context.Provider>,
  "root",
)

// Hot Module Replacement (HMR) - Remove this snippet to remove HMR.
// Learn more: https://www.snowpack.dev/#hot-module-replacement
@scope(("import", "meta")) @val external hot: bool = "hot"

@scope(("import", "meta", "hot")) @val
external accept: unit => unit = "accept"

if hot {
  accept()
}
