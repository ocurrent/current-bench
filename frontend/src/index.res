let url: string = %raw(`import.meta.env.VITE_OCAML_BENCH_GRAPHQL_URL`)

let client = ReScriptUrql.Client.make(~url, ())

ReactDOM.render(
  <ReScriptUrql.Context.Provider value=client> <App /> </ReScriptUrql.Context.Provider>,
  ReactDOM.querySelector("#root")->Belt.Option.getExn,
)
