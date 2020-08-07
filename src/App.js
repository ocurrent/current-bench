import React, { useState, useEffect } from "react";
import Navbar from "./Navbar.js";
import MetricSelector from "./MetricSelector.js";
import Graph from "./Graph.js";
import { ThemeProvider } from "@material-ui/core/styles";
import { Box, Container, Grid, Divider } from "@material-ui/core";
import "./App.css";
import { length, mapAccum, isNil, map } from "ramda";

import theme from "./theme.js";

import gql from "graphql-tag";
import ApolloClient from "apollo-client";
import { InMemoryCache } from "apollo-cache-inmemory";
import { HttpLink } from "apollo-link-http";

require('dotenv').config();
const graphql_key = process.env['REACT_APP_GRAPHQL_KEY'];

const client = new ApolloClient({
  link: new HttpLink({
    uri: "http://localhost:8080/v1/graphql",
    headers: {
      'x-hasura-admin-secret': graphql_key
    },
  }),
  cache: new InMemoryCache(),
});

const GET_DATA = gql`
  query {
    benchmarksrun {
      commits
      name
      mbs_per_sec
      ops_per_sec
      time
    }
  }
`;

function benchmarkToChart(results) {
  const len = length(results);

  const [_, result] = mapAccum(
    (index, { hash, stats }) => {
      let time = stats["time"];

      let opsPerSec = stats["ops_per_sec"];

      let mbsPerSec = stats["mbs_per_sec"];

      return [
        index + 1,
        {
          name: hash,
          relCommit: index - len + 1,
          time: time,
          timeLimit: [],
          opsPerSec: opsPerSec,
          opsPerSecLimit: [],
          mbsPerSec: mbsPerSec,
          mbsPerSecLimit: [],
        },
      ];
    },
    0,
    results
  );

  return result;
}

function App() {
  const [data, setData] = useState({ data: { benchmarksrun: [] } });

  useEffect(() => {
    async function fetchData() {
      client
        .query({
          query: GET_DATA,
        })
        .then((result) => setData(result.data));
    }
    fetchData();
  }, []);

  const title = "mirage/index";

  let data_info = [];
  if (data.hasOwnProperty("benchmarksrun")) {
    data_info = data["benchmarksrun"];
  } else {
    data_info = data["data"]["benchmarksrun"];
  }

  function getCommit(obj) {
    return obj["commits"];
  }
  //Get all commits
  const commits = Array.from(new Set(data_info.map(getCommit)));

  function getName(obj) {
    return obj["name"];
  }

  const benchmarkNames = Array.from(new Set(data_info.map(getName)));

  var benches = [];

  function getData(name, obj) {
    if (name === obj["name"]) {
      return {
        name: obj["name"],
        hash: obj["commits"],
        stats: {
          time: obj["time"],
          ops_per_sec: obj["ops_per_sec"],
          mbs_per_sec: obj["mbs_per_sec"],
        },
      };
    }
  }

  if (!isNil(benchmarkNames)) {
    benches = map((name) => {
      const results = commits.map(() => {
        const all = data_info.map((obj) => getData(name, obj));
        return all;
      })[0];

      const filtered_results = results.filter((el) => el !== undefined);
      const chart = benchmarkToChart(filtered_results);

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
              <MetricSelector metrics={["a", "b", "c"]} />
            </Container>
          </Box>
          <Divider variant="middle" />
          <Box mt={2}>
            <Grid container spacing={2}>
              {benches.map((bench) => (
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
