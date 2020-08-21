import React, { useState, useEffect } from "react";
import Navbar from "./Navbar.js";
import MetricSelector from "./MetricSelector.js";
import Graph from "./Graph.js";
import { ThemeProvider } from "@material-ui/core/styles";
import { Box, Container, Grid, Divider } from "@material-ui/core";
import ListItemText from '@material-ui/core/ListItemText';
import ListItem from '@material-ui/core/ListItem';
import "./App.css";
import { length, mapAccum, isNil, map } from "ramda";
import { BrowserRouter as Router, Route, Link} from 'react-router-dom';

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
      branch
    }
  }
`;

function benchmarkToChart(results) {
  const len = length(results);

  const [_, result] = mapAccum(
    (index, { hash, branch, stats }) => {
      let time = stats["time"];

      let opsPerSec = stats["ops_per_sec"];

      let mbsPerSec = stats["mbs_per_sec"];

      return [
        index + 1,
        {
          name: hash,
          branch: branch,
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

function getBenchCharts(pr) {
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

  function getBranch(obj) {
    return obj['branch'];
  }

  branches = Array.from(new Set(data_info.map(getBranch)));

  function getData(name, obj) {
    if (name === obj["name"] && (pr.includes(obj['branch']) || obj['branch'].includes('master') )) {
      return {
        name: obj["name"],
        hash: obj["commits"],
        branch: obj['branch'],
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
}

const HomePage = () => {
  getBenchCharts("master");
  return (
    <ThemeProvider theme={theme}>
        <Container maxWidth="md">
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
  );
};


const PRSPage = () => {
return (
    <>
       <ThemeProvider theme={theme}>
        <Container maxWidth="md">
          <Box mt={2}>
            <Grid container spacing={2}>
      {branches.map((branch, _) => (
        <h5 key={branch}>
          <ListItem button component={Link} to={`/pr/${branch}`}>
          <ListItemText>{branch}</ListItemText>
        </ListItem>
        </h5>
      ))}
           </Grid>
          </Box>
        </Container>
      </ThemeProvider>

    </>
  );
};

const PRPage = ( {match}) => {
  getBenchCharts(match.url);
  return (
    <ThemeProvider theme={theme}>
        <Container maxWidth="md">
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
  );

};

var benches = [];
var branches = [];
var data, setData;

function App() {
  [data, setData] = useState({ data: { benchmarksrun: [] } });

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

  getBenchCharts("master");


 const title = "mirage/index";

  return (
    <div className="App">
      <Router>
      <Navbar title={title} />
      <Route exact path="/" component={HomePage} />
      <Route exact path="/prs" component={PRSPage}/>
      <Route path="/pr/:owner/:name/:pr" component={PRPage} />
     </Router> 
    </div>
  );
}

export default App;
