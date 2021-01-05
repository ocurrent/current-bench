%%raw(`import './App.css';`)

let jsonFieldExn = (type a, json, field, kind: Js.Json.kind<a>): a => {
  open Belt
  let x = json->Js.Json.decodeObject->Option.getExn->Js.Dict.get(field)->Option.getExn
  switch kind {
  | Js.Json.String => Js.Json.decodeString(x)->Option.getExn
  | Js.Json.Number => Js.Json.decodeNumber(x)->Option.getExn
  | Js.Json.Object => Js.Json.decodeObject(x)->Option.getExn
  | Js.Json.Array => Js.Json.decodeArray(x)->Option.getExn
  | Js.Json.Boolean => Js.Json.decodeBoolean(x)->Option.getExn
  | Js.Json.Null => (Obj.magic(Js.Json.decodeNull(x)->Option.getExn): Js.Types.null_val)
  }
}

open Components

// Styling eXtensions
module Sx = Sx.Make({
  let theme = {
    ...Sx.default,
    fontSizes: {
      xs: 12,
      sm: 14,
      md: 16,
      lg: 18,
      xl: 20,
      xl2: 24,
      xl3: 32,
      xl4: 48,
      xl5: 56,
      xl6: 72,
    },
  }
})

module GetBenchmarks = %graphql(`
query {
  benchmarks {
      repositories
      json_data
      commits
      branch
      timestamp
    }
  }
`)

type testResults = {
  name: string,
  commit: string,
  metrics: Js.Dict.t<float>,
}

let commitUrl = commit => `https://github.com/mirage/index/commit/${commit}`
let goToCommitLink = commit => {
  let openUrl: string => unit = %raw(`function (url) { window.open(url, "_blank") }`)
  openUrl(commitUrl(commit))
}

module BenchmarkTest = {
  let groupByTestName = (acc, item: testResults, idx) => {
    let go = vOpt => {
      let idxs = switch vOpt {
      | Some(idxs) => idxs
      | None => Belt.Set.Int.empty
      }
      Some(Belt.Set.Int.add(idxs, idx))
    }
    Belt.Map.String.update(acc, item.name, go)
  }

  let decodeMetricValue = json => {
    switch Js.Json.classify(json) {
    | JSONNumber(n) => n
    | JSONArray([]) => 0.0
    | JSONArray(ns) =>
      Belt.Array.get(ns, 0)->Belt.Option.getExn->Js.Json.decodeNumber->Belt.Option.getExn
    | _ => invalid_arg("Invalid metric value: " ++ Js.Json.stringify(json))
    }
  }

  let getTestResults = (item: GetBenchmarks.t_benchmarks): array<testResults> => {
    item.json_data
    ->Belt.Option.getExn
    ->jsonFieldExn("result", Js.Json.Object)
    ->Js.Dict.get("results")
    ->Belt.Option.getExn
    ->Js.Json.decodeArray
    ->Belt.Option.getExn
    ->Belt.Array.map(result => {
      {
        name: jsonFieldExn(result, "name", Js.Json.String),
        metrics: jsonFieldExn(result, "metrics", Js.Json.Object) |> Js.Dict.map((. v) =>
          decodeMetricValue(v)
        ),
        commit: item.commits,
      }
    })
  }

  let collectMetricsByKey = (
    ~metric_name,
    items: array<testResults>,
    selection: Belt.Set.Int.t,
  ) => {
    let data = Belt.Array.makeUninitializedUnsafe(Belt.Set.Int.size(selection))
    Belt.Set.Int.reduce(selection, 0, (i, idx) => {
      let item: testResults = Belt.Array.getExn(items, idx)
      let metricWithIndex = [
        idx->float_of_int,
        item.metrics->Js.Dict.get(metric_name)->Belt.Option.getExn,
      ]
      Belt.Array.setExn(data, i, metricWithIndex)
      i + 1
    })->ignore
    data
  }

  let renderMetricRow = (~metric_name, ~commit, ~second_to_last_value, ~last_value) => {
    let delta = {
      let n = if second_to_last_value == 0.0 {
        0.0
      } else {
        let n = (second_to_last_value -. last_value) /. second_to_last_value *. 100.
        last_value < second_to_last_value ? -.n : abs_float(n)
      }
      if n > 0.0 {
        "+" ++ n->Js.Float.toFixedWithPrecision(~digits=2) ++ "%"
      } else {
        n->Js.Float.toFixedWithPrecision(~digits=2) ++ "%"
      }
    }
    <Table.Row key=metric_name>
      <Table.Col> {Rx.text(metric_name)} </Table.Col>
      <Table.Col> <Link target="_blank" href={commitUrl(commit)} text=commit /> </Table.Col>
      <Table.Col> {Rx.text(last_value->Js.Float.toFixedWithPrecision(~digits=2))} </Table.Col>
      <Table.Col sx=[Sx.text.right]> {Rx.text(delta)} </Table.Col>
    </Table.Row>
  }

  @react.component
  let make = (~dataframe, ~test_name, ~selection, ~synchronize=true) => {
    // TODO: Extract from payload
    let metric_names = [
      "mbs_per_sec",
      "merge_durations_us",
      "nb_merges",
      "ops_per_sec",
      "read_amplification_calls",
      "read_amplification_size",
      "replace_durations",
      "time",
      "write_amplification_calls",
      "write_amplification_size",
    ]
    let graphRefs = ref(list{})
    let onGraphRender = graph => graphRefs := Belt.List.add(graphRefs.contents, graph)

    let xTicks = selection->Belt.Set.Int.reduce(Belt.Map.Int.empty, (acc, idx) => {
      let item: testResults = Belt.Array.getExn(dataframe, idx)
      let tick = item.commit
      let tick = String.length(tick) > 7 ? String.sub(tick, 0, 7) : tick
      Belt.Map.Int.set(acc, idx, tick)
    })

    React.useEffect1(() => {
      if synchronize {
        LineGraph.synchronize(graphRefs.contents->Belt.List.toArray)
      }
      None
    }, [synchronize])

    let metric_table = {
      <Table>
        <thead>
          <tr className={Sx.make([Sx.h.xl2])}>
            <th> {React.string("Metric")} </th>
            <th> {React.string("Last Commit")} </th>
            <th> {React.string("Last Value")} </th>
            <th> {React.string("Delta")} </th>
          </tr>
        </thead>
        <tbody>
          {metric_names
          ->Belt.Array.map(metric_name => {
            // TODO: Avoid recomputation of data
            let data = collectMetricsByKey(~metric_name, dataframe, selection)
            let second_to_last_value =
              Belt.Array.getExn(data, Belt.Array.length(data) - 2)->Belt.Array.getExn(1)
            let last_value =
              Belt.Array.getExn(data, Belt.Array.length(data) - 1)->Belt.Array.getExn(1)
            let idx = Belt.Array.getExn(data, Belt.Array.length(data) - 1)->Belt.Array.getExn(0)
            let commit = Belt.Map.Int.getExn(xTicks, idx->Belt.Float.toInt)

            {
              renderMetricRow(~metric_name, ~commit, ~second_to_last_value, ~last_value)
            }
          })
          ->Rx.array}
        </tbody>
      </Table>
    }

    let metric_graphs =
      metric_names
      ->Belt.Array.map(metric_name => {
        let data = collectMetricsByKey(~metric_name, dataframe, selection)

        <LineGraph
          onXLabelClick=goToCommitLink
          onRender=onGraphRender
          key=metric_name
          title=metric_name
          xTicks
          data
          labels=["idx", "value"]
        />
      })
      ->Rx.array

    <details className={Sx.make([Sx.w.full])} open_=true>
      <summary className={Sx.make([Sx.pointer])}>
        <Text sx=[Sx.text.xl3, Sx.text.bold]> {Rx.text(test_name)} </Text>
      </summary>
      <VStack sx=[Sx.mt.xl]> metric_table <Flex wrap=true> metric_graphs </Flex> </VStack>
    </details>
  }
}

module BenchmarkResults = {
  @react.component
  let make = (~synchronize) => {
    let ({ReasonUrql.Hooks.response: response}, _) = ReasonUrql.Hooks.useQuery(
      ~query=module(GetBenchmarks),
      (),
    )

    switch response {
    | Fetching => Rx.string("Loading...")
    | Data(data)
    | PartialData(data, _) =>
      let dataframe =
        data.benchmarks
        ->Belt.Array.slice(~offset=0, ~len=20)
        ->Belt.Array.map(BenchmarkTest.getTestResults)
        ->Belt.Array.concatMany
      let selectionByTestName =
        dataframe->Belt.Array.reduceWithIndex(Belt.Map.String.empty, BenchmarkTest.groupByTestName)

      let graphs = {
        selectionByTestName
        ->Belt.Map.String.mapWithKey((test_name, selection) =>
          <BenchmarkTest synchronize key={test_name} dataframe test_name selection />
        )
        ->Belt.Map.String.valuesToArray
        ->Rx.array
      }

      <VStack spacing=Sx.xl3> graphs </VStack>

    | Error(e) =>
      switch e.networkError {
      | Some(_e) => <div> {"Network Error"->React.string} </div>
      | None => <div> {"Other Error"->React.string} </div>
      }
    | Empty => <div> {"Something went wrong!"->React.string} </div>
    }
  }
}

@react.component
let make = () => {
  let url = ReasonReact.Router.useUrl()

  let (synchronize, setSynchronize) = React.useState(() => false)
  let onSynchronizeToggle = () => {
    setSynchronize(v => !v)
  }

  <div className={Sx.make([Sx.container, Sx.d.flex, Sx.flex.wrap])}>
    <div className={Sx.make(Styles.sidebarSx)}>
      <HStack spacing=Sx.lg>
        <Block sx=[Sx.w.xl2, Sx.mt.xl]> <Icon svg=Icon.ocaml /> </Block>
        <Heading text="Benchmarks" />
      </HStack>
      <VStack stretch=true spacing=Sx.md>
        <Link active={url.hash == "/#"} href="#" icon=Icon.bolt text="mirage/index" />
      </VStack>
      <Field sx=[Sx.mb.md, Sx.self.end, Sx.mt.auto] label="Settings">
        <HStack spacing=#between>
          {React.string("Synchronize graphs")}
          <Switch onToggle=onSynchronizeToggle on=synchronize />
        </HStack>
      </Field>
    </div>
    <div className={Sx.make(Styles.topbarSx)}>
      <HStack spacing=#between>
        <Text sx=[Sx.text.bold]> {Rx.text("Results")} </Text>
        <Link href="https://github.com/mirage/index" sx=[Sx.mr.xl] icon=Icon.github />
      </HStack>
    </div>
    <div className={Sx.make(Styles.mainSx)}>
      {switch url.hash {
      | "" => <BenchmarkResults synchronize />
      | "/showcase" => <Showcase />
      | _ => <h1> {Rx.string("Unknown route")} </h1>
      }}
    </div>
  </div>
}
