let fetchOptions = ReScriptUrql.Client.FetchOpts(
  Fetch.RequestInit.make(
    ~headers=Fetch.HeadersInit.make({"X-Hasura-Admin-Secret": "zbNoMU69kxiw"}),
    (),
  ),
)

let url: string = %raw(`import.meta.env.VITE_GRAPHQL_URL`)

let client = ReScriptUrql.Client.make(~url, ~fetchOptions, ())

ReactDOM.render(
  <ReScriptUrql.Context.Provider value=client> <App /> </ReScriptUrql.Context.Provider>,
  ReactDOM.querySelector("#root")->Belt.Option.getExn,
)
