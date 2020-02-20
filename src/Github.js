const query = /* GraphQL */ `
  query {
    repository(owner: "typelevel", name: "cats") {
      ref(qualifiedName: "master") {
        target {
          ... on Commit {
            history(first: 10) {
              pageInfo {
                hasNextPage
                endCursor
              }
              edges {
                node {
                  oid
                  messageHeadline
                }
              }
            }
          }
        }
      }
    }
  }
`;
