import { makeExecutableSchema } from "graphql-tools";
import benchmarkData from "./data/data.json";

const typeDefs = `
type Datum {
  time: Float!
  ops_per_sec: Float!
  mbs_per_sec: Float!
  read_amplification_calls: Float!
  read_amplification_size: Float!
  write_amplification_calls: Float!
  write_amplification_size: Float!
}

type Benchmark {
  name: String!
  metrics: Datum!
}

type BenchmarkRun {
  data: [Benchmark]
}

type Commit {
  hash: String!
  benchmarkRuns: [BenchmarkRun]!
}

type Repository {
  name: String!
  commits: [Commit]!
}

# the schema allows the following query:
type Query {
  repositories: [Repository]
}

# we need to tell the server which types represent the root query
# and root mutation types. We call them RootQuery and RootMutation by convention.
schema {
  query: Query
}
`;

const processData = data => {
  return data.map(({ name, commits }) => {
    return {
      name: name,
      commits: commits.map(({ hash, results }) => {
        return {
          hash: hash,
          benchmarkRuns: results.map(({ results }) => {
            return {
              data: Object.entries(results).map(([name, metrics]) => {
                return { name: name, metrics: metrics };
              })
            };
          })
        };
      })
    };
  });
};

const resolvers = {
  Query: {
    repositories: () => processData(benchmarkData)
  }
};

export const schema = makeExecutableSchema({ typeDefs, resolvers });
