import React, { useState, useEffect } from "react";
import { standardDeviation, randomHash } from "./utils.js";
import { graphql } from "graphql";
import {
  ComposedChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  Label,
  Area
} from "recharts";
import { schema } from "./Mock.js";
import "./App.css";
import {
  T,
  always,
  pipe,
  multiply,
  unfold,
  reverse,
  length,
  append,
  curry,
  find,
  mapAccum,
  filter,
  flatten,
  concat,
  equals,
  cond,
  fromPairs,
  union,
  prop,
  identity,
  isNil,
  lensProp,
  keys,
  map,
  mean,
  mergeWith,
  over,
  path,
  reduce,
  set,
  sum,
  toPairs,
  objOf
} from "ramda";

const query = /* GraphQL */ `
  query {
    repositories {
      name
      commits {
        hash
        benchmarkRuns {
          data {
            name
            metrics {
              time
            }
          }
        }
      }
    }
  }
`;

const CustomTooltip = ({ active, payload, label }) => {
  if (active) {
    const commitRel = payload[0].value;
    const branch = "master";
    const ref = equals(label, 0) ? branch : `${branch}~${-label}`;

    return (
      <div className="custom-tooltip">
        <p className="label">{`${ref} : ${payload[0].value}`}</p>
        <p className="desc">Anything you want can be displayed here.</p>
      </div>
    );
  }

  return null;
};

function benchmarkToChart(results) {
  const len = length(results);

  const [_, result] = mapAccum(
    (time, { hash, stats }) => {
      let shortHash = hash.substring(0, 8);

      let { mean, standardDeviation } = stats[0];

      return [
        time + 1,
        {
          name: shortHash,
          relCommit: time - len + 1,
          time: mean,
          timeLimit: [mean - standardDeviation, mean + standardDeviation]
        }
      ];
    },
    0,
    results
  );

  console.log(result);
  return result;
}

function generateFakeData(lastCommit) {
  function inner([prev, size]) {
    if (equals(size, 0)) return false;

    const delta = (Math.random() - 0.5) * 0.005;
    const delta2 = (Math.random() - 0.5) * 0.1;
    const delta3 = (Math.random() - 0.5) * 0.1;

    const stats = map(({ name, mean, standardDeviation }) => {
      return {
        name: name,
        mean: multiply(mean, 1.02 + delta2) + delta,
        standardDeviation: multiply(standardDeviation, delta3)
      };
    }, prev.stats);

    const commit = {
      hash: randomHash(),
      stats: stats
    };

    return [commit, [commit, size - 1]];
  }

  const result = reverse(unfold(inner, [lastCommit, 50]));
  return result;
}

// Take an array of metrics and aggregate them, computing mean and standard deviation
function metricCompute(metrics) {
  const ks = reduce(union, [], map(k => keys(k), metrics));

  return map(key => {
    const values = map(prop(key), metrics);

    const valuesMean = mean(values);
    const valuesStandardDeviation = standardDeviation(values);

    return {
      name: key,
      mean: valuesMean,
      standardDeviation: valuesStandardDeviation
    };
  }, ks);
}

const mapNil = curry((f, xs) => {
  if (isNil(xs)) return xs;
  return map(f, xs);
});

const nilGuard = f => cond([[isNil, identity], [T, f]]);

function App() {
  const [data, setData] = useState({ data: { repositories: [] } });

  useEffect(() => {
    async function fetchData() {
      const result = await graphql(schema, query);

      setData(result.data);
    }
    fetchData();
  }, []);

  const repo = path(["repositories", 0], data);
  const title = path(["name"], repo);

  // Get the list of all benchmarks

  const commits = prop("commits", repo);
  const benchmarkNames = commits
    ? reduce(
        union,
        [],
        mapNil(
          pipe(
            prop("benchmarkRuns"),
            map(prop("data")),
            map(map(prop("name"))),
            reduce(union, [])
          ),
          commits
        )
      )
    : commits;

  var benches = [];

  if (!isNil(benchmarkNames)) {
    benches = map(name => {
      const results = commits.map(commit => {
        const all = commit.benchmarkRuns.map(({ data }) => data);
        const flattened = flatten(all);
        const some = filter(r => equals(name, r.name), flattened);
        const fewer = map(({ metrics }) => metrics, some);
        const last = metricCompute(fewer);

        const bar = { hash: commit.hash, stats: last };

        const foo = generateFakeData(bar);

        return foo;
      })[0];

      const chart = benchmarkToChart(results);

      return { name: name, chart: chart };
    }, benchmarkNames);

    console.log(benches[0]);
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>
          Benchmarks for{" "}
          <a className="App-header-link" href="https://github.com/mirage/index">
            {title}
          </a>
          .
        </h1>
      </header>
      <div className="content" />
      {benches.map(bench => (
        <div className="App-chart-container">
          <h2>{bench.name}</h2>
          <ComposedChart
            width={700}
            height={500}
            data={bench.chart}
            margin={{
              top: 5,
              right: 30,
              left: 20,
              bottom: 5
            }}
          >
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="relCommit" />
            <YAxis>{/* <Label value="Time" /> */}</YAxis>
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <Area
              type="monotone"
              dataKey="timeLimit"
              stroke="none"
              fill="#dfdaf4"
            />
            <Line type="monotone" dataKey="time" stroke="#8884d8" />
          </ComposedChart>
        </div>
      ))}
    </div>
  );
}

export default App;
