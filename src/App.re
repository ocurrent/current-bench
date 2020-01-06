module Benchmark = {
  type single = {
    name: string,
    y_units: string,
    results: array(int),
  };

  type t = {
    commit: string,
    benchmarks: array(single),
  };
};

let random_benchmarks = () => {
  let random_series = () => {
    let base = Random.int(10);
    [|base + Random.int(3), base + Random.int(3), base + Random.int(3)|];
  };

  Benchmark.(
    [|
      {
        name: "write_sync",
        y_units: "microseconds per op",
        results: random_series(),
      },
      {
        name: "read_sync",
        y_units: "microseconds per op",
        results: random_series(),
      },
    |]
  );
};

let link_of_commit_hash = (~org, ~repo, ~hash) =>
  Format.sprintf("https://github.com/%s/%s/tree/%s", org, repo, hash);

let benches: array(Benchmark.t) =
  Benchmark.(
    [|
      {
        commit: "0adda73019f9f3a947c224b37ceb54d0f36d5fc4",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "66fa77bc7ef21c49f567330fc94f1d0c69a4c9aa",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "770fab4f7a5ef0f38b9e13551298c4f94463fc1e",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "52e21ac0f67e55184780e5cdaecc45ba2fc655d0",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "9f737441b7fe7948d1031155e96bef358dcac633",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "c628c9ee8c91eaf611700fc20e8ade44c41d9fc1",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "5f8b5df455f1b895272e3fc0ec0fbbba2ade38ca",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "86aa2fb1169ec711d8fb3bc35ab2c7ec3bc23e26",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "749949ec747c9f379bdae820dbee5819d600e073",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "ed6feaf89d2f50a06786950f3293bd9175c8367b",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "c42c663acb97c9b30edd575d8e2b9985aab2b4c9",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "a899d2fa286e129241cda520c20b321fdca05f50",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "de56e7988855e84c3f2a6a58bc4ecff1983bdf83",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "71b42fd29354bb4dc333a6973f27f163d90aa596",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "b746b66ccb0aad90c9c3da3fc659e0a1dd8ca4f3",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "3466767f37ac273eb2dccd111838674e86db6663",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "dc576caa5ee0426ccdb43725728e3c3519c46950",
        benchmarks: random_benchmarks(),
      },
      {
        commit: "7ba3081fd6386a62815200c432d1a682f12b62a3",
        benchmarks: random_benchmarks(),
      },
    |]
  );

let benchmarks_to_display: array(Benchmark.t) => array(string) =
  benches =>
    benches
    |> Array.to_list
    |> List.map(x =>
         x.Benchmark.benchmarks
         |> Array.map(b => b.Benchmark.name)
         |> Array.to_list
       )
    |> List.flatten
    |> List.sort_uniq(compare)
    |> Array.of_list;

let spec_of_bench: (array(Benchmark.t), string) => Chart.chart_spec =
  (benches, tag) => {
    let xdata =
      benches
      |> Array.map((Benchmark.{commit, benchmarks}) =>
           benchmarks
           |> Array.to_list
           |> List.filter((Benchmark.{name, _}) => String.equal(name, tag))
           |> List.hd
           |> ((Benchmark.{results, _}) => (commit, results[0]))
         );

    Chart.{title: tag, yunit: "microsec/op", xdata};
  };

// -----------------------------------------------------------------------------
// TODO: remove static state
// -----------------------------------------------------------------------------

let org = "mirage";
let repo = "index";

// -----------------------------------------------------------------------------

[@react.component]
let make = () => {
  let specs =
    benches |> benchmarks_to_display |> Array.map(spec_of_bench(benches));
  let latest_commit =
    benches
    |> Array.to_list
    |> List.rev
    |> List.hd
  |> ((Benchmark.{commit, _}) => commit);
  let latest_commit_short = latest_commit |> Utils.short_hash;
  <>
    /* React.useEffect0(() => Some(() => Js.log(generate(chart)))); */
    <div className="header">
      <h1>
        {React.string("Benchmarks for ")}
        <a href="https://github.com/mirage/index">
          {React.string(org ++ "/" ++ repo)}
        </a>
        {React.string(".")}
      </h1>
    </div>
    <div className="content">
      <p>
        {React.string("Latest commit is commit ")}
        <a
          href={link_of_commit_hash(~org, ~repo, ~hash=latest_commit)}>
          {React.string(latest_commit_short)}
        </a>
        {React.string(".")}
      </p>
      {specs |> Array.map(spec => <Chart spec />) |> ReasonReact.array}
    </div>
  </>;
};
