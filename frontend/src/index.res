let fetchOptions = ReScriptUrql.Client.FetchOpts(
  Fetch.RequestInit.make(
    ~headers=Fetch.HeadersInit.make({"X-Hasura-Admin-Secret": "zbNoMU69kxiw"}),
    (),
  ),
)

let client = ReScriptUrql.Client.make(
  ~url="http://autumn.ocamllabs.io:8080/v1/graphql",
  ~fetchOptions,
  (),
)

ReactDOM.render(
  <ReScriptUrql.Context.Provider value=client> <App /> </ReScriptUrql.Context.Provider>,
  ReactDOM.querySelector("#root")->Belt.Option.getExn,
)
