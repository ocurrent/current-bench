type route =
  | Main
  | Repo({repoId: string, benchmarkName: option<string>})
  | RepoPull({repoId: string, pullNumber: int, benchmarkName: option<string>})

type error = {
  path: list<string>,
  reason: string,
}

let route = (url: RescriptReactRouter.url) =>
  switch url.path {
  | list{} => Ok(Main)
  | list{orgName, repoName} => Ok(Repo({repoId: orgName ++ "/" ++ repoName, benchmarkName: None}))
  | list{orgName, repoName, "benchmark", benchmarkName} =>
    Ok(Repo({repoId: orgName ++ "/" ++ repoName, benchmarkName: Some(benchmarkName)}))
  | list{orgName, repoName, "pull", pullNumberStr} =>
    switch Belt.Int.fromString(pullNumberStr) {
    | Some(pullNumber) =>
      Ok(
        RepoPull({
          repoId: orgName ++ "/" ++ repoName,
          pullNumber: pullNumber,
          benchmarkName: None,
        }),
      )
    | None => Error({path: url.path, reason: "Invalid pull number: " ++ pullNumberStr})
    }
  | list{orgName, repoName, "pull", pullNumberStr, "benchmark", benchmarkName} =>
    switch Belt.Int.fromString(pullNumberStr) {
    | Some(pullNumber) =>
      Ok(
        RepoPull({
          repoId: orgName ++ "/" ++ repoName,
          pullNumber: pullNumber,
          benchmarkName: Some(benchmarkName),
        }),
      )
    | None => Error({path: url.path, reason: "Invalid pull number: " ++ pullNumberStr})
    }
  | _ => Error({path: url.path, reason: "Unknown route: /" ++ String.concat("/", url.path)})
  }

let path = route =>
  switch route {
  | Main => "/"
  | Repo({repoId, benchmarkName: None}) => "/" ++ repoId
  | Repo({repoId, benchmarkName: Some(benchmarkName)}) =>
    "/" ++ repoId ++ "/benchmark/" ++ benchmarkName
  | RepoPull({repoId, pullNumber, benchmarkName: None}) =>
    "/" ++ repoId ++ "/pull/" ++ Belt.Int.toString(pullNumber)
  | RepoPull({repoId, pullNumber, benchmarkName: Some(benchmarkName)}) =>
    "/" ++ repoId ++ "/pull/" ++ Belt.Int.toString(pullNumber) ++ "/benchmark/" ++ benchmarkName
  }

let useRoute = () => RescriptReactRouter.useUrl()->route

let go = route => RescriptReactRouter.push(path(route))
