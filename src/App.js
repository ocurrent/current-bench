import React, { useState, useEffect } from "react";
import { standardDeviation } from "./utils.js";
import { generateFakeData } from "./faker.js";
import { graphql } from "graphql";
import Navbar from "./Navbar.js";
import MetricSelector from "./MetricSelector.js";
import Graph from "./Graph.js";
import { ThemeProvider } from "@material-ui/core/styles";
import { Box, Container, Grid, Divider } from "@material-ui/core";
import { schema } from "./Mock.js";
import "./App.css";
import {
  pipe,
  length,
  curry,
  find,
  mapAccum,
  filter,
  flatten,
  equals,
  union,
  prop,
  isNil,
  keys,
  map,
  mean,
  path,
  reduce
} from "ramda";

import theme from "./theme.js";

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
              ops_per_sec
            }
          }
        }
      }
    }
  }
`;

function benchmarkToChart(results) {
  const len = length(results);

  const [_, result] = mapAccum(
    (index, { hash, stats }) => {
      let shortHash = hash.substring(0, 8);

      let time = find(({ name }) => equals(name, "time"), stats);
      let opsPerSec = find(({ name }) => equals(name, "ops_per_sec"), stats);

      return [
        index + 1,
        {
          name: shortHash,
          relCommit: index - len + 1,
          time: time.mean,
          timeLimit: [
            time.mean - time.standardDeviation,
            time.mean + time.standardDeviation
          ],
          opsPerSec: opsPerSec.mean,
          opsPerSecLimit: [
            opsPerSec.mean - opsPerSec.standardDeviation,
            opsPerSec.mean + opsPerSec.standardDeviation
          ]
        }
      ];
    },
    0,
    results
  );

  console.log(result);
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

function App() {
  const [data, setData] = useState({ data: { repositories: [] } });

  const [searchTerm, setSearchTerm] = React.useState("");
  const handleSearchTermChange = event => {
    setSearchTerm(event.target.value);
  };

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
  }

  return (
    <div className="App">
      <ThemeProvider theme={theme}>
        <Navbar title={title} />
        <Container maxWidth="1700px">
          <Box p={2}>
            <Container>
              <MetricSelector metrics={["a", "b"]} />
            </Container>
          </Box>
          <Divider variant="middle" />
          <Box mt={2}>
            <Grid container spacing={2}>
              {benches.map(bench => (
                <Grid item xs>
                  <Graph bench={bench} />
                </Grid>
              ))}
            </Grid>
          </Box>
        </Container>
      </ThemeProvider>
    </div>
  );
}

export default App;
