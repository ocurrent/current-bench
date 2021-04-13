let host: string = %raw(`import.meta.env.VITE_OCAML_BENCH_HOST`)
let port: string = %raw(`import.meta.env.VITE_OCAML_BENCH_GRAPHQL_PORT`)

let url: string = host ++ ":" ++ port ++ "/v1/graphql"

let client = ReScriptUrql.Client.make(~url, ())

ReactDOM.render(
  <ReScriptUrql.Context.Provider value=client> <App /> </ReScriptUrql.Context.Provider>,
  ReactDOM.querySelector("#root")->Belt.Option.getExn,
)
