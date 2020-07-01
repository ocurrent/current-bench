import React, { useState, useEffect } from "react";
import Navbar from "./Navbar.js";
import MetricSelector from "./MetricSelector.js";
import Graph from "./Graph.js";
import { ThemeProvider } from "@material-ui/core/styles";
import { Box, Container, Grid, Divider } from "@material-ui/core";
import "./App.css";
import {
  length,
  mapAccum,
  isNil,
  map,
} from "ramda";

import theme from "./theme.js";

import gql from 'graphql-tag';
 import ApolloClient from 'apollo-client';
 import { InMemoryCache } from 'apollo-cache-inmemory';
 import { HttpLink } from 'apollo-link-http';


 const client = new ApolloClient({
link: new HttpLink({
       uri: 'http://localhost:8080/v1/graphql',
       headers: {}
     }),
     cache: new InMemoryCache(),
});

 const GET_DATA = gql`
 query  {
  benchmarksrun {
    commits
    name
    mbs_per_sec
    ops_per_sec
    time
  }
}`;

function benchmarkToChart(results) {
  const len = length(results);

  const [_, result] = mapAccum(
    (index, { hash, stats }) => {

      console.log('hash and stats');
      console.log(hash);
      console.log(stats);
      let time = stats['time'];

      console.log("found time in the obj");
      console.log(time);

      let opsPerSec = stats['ops_per_sec'];

      console.log("found ops_per_sec in ")

      let mbsPerSec = stats['mbs_per_sec'];

      return [
        index + 1,
        {
          name: hash,
          relCommit: index - len + 1,
          time: time,
          timeLimit: [
          ],
          opsPerSec: opsPerSec,
          opsPerSecLimit: [
          ],
          mbsPerSec: mbsPerSec,
          mbsPerSecLimit: [
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
// function metricCompute(metrics) {
//   const ks = reduce(union, [], map(k => keys(k), metrics));

//   return map(key => {
//     const values = map(prop(key), metrics);

//     const valuesMean = mean(values);
//     const valuesStandardDeviation = standardDeviation(values);

//     return {
//       name: key,
//       mean: valuesMean,
//       standardDeviation: valuesStandardDeviation
//     };
//   }, ks);
// }

function App() {

     const [data, setData] = useState({ data: { benchmarksrun: [] } });

  useEffect(() => {
     async function fetchData() {
     client
     .query({
         query: GET_DATA  })
      .then(result => setData(result.data));
   
      
      //  const result = await graphql(schema, query); 

      //  setData(result.data);
    }
    fetchData();
  }, []);
 
    console.log(data);
  // const repo = "mirage/index";
  const title = "mirage/index";

  let data_info = []
  if (data.hasOwnProperty('benchmarksrun')) {
    data_info = data['benchmarksrun']
  } else {
    data_info = data['data']['benchmarksrun']
  }

  function getCommit (obj) {
    return obj['commits'];
  }
  //Get all commits
  const commits = Array.from(new Set(data_info.map(getCommit)));
  
  
  function getName(obj) {
    return obj['name'];
  }

   const benchmarkNames = Array.from(new Set(data_info.map(getName)));

  var benches = [];

  function getData(obj, commit) {
    return {
      'hash': commit,
      'stats': {
        'time': obj['time'],
        'ops_per_sec': obj['ops_per_sec'],
        'mbs_per_sec': obj['mbs_per_sec']
      }
    };
  }

  if (!isNil(benchmarkNames)) {
    benches = map(name => {
      const results = commits.map(commit => {
        const all = data_info.map(obj => getData(obj, commit));
        return all;
      })[0];

      console.log("results");
      console.log(results);
      const chart = benchmarkToChart(results);

      return { name: name, chart: chart };
    }, benchmarkNames);
  }

  console.log("benchmarks");
  console.log(benches);

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
