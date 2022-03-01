type worker = option<(string, string)>

type route =
  | Main
  | Repo({repoId: string, benchmarkName: option<string>, worker: worker})
  | RepoPull({repoId: string, pullNumber: int, benchmarkName: option<string>, worker: worker})

type error = {
  path: list<string>,
  reason: string,
}

let parseParams = (query) => {
  Js.String.split("&", query)
  ->Belt.Array.keepMap((part) => {
      switch Js.String.split("=", part) {
        | [ key, value ] => Some((key, Js.Global.decodeURIComponent(value)))
        | _ => None
      }
  })
}

let getWorker = (query) => {
  let params = parseParams(query)
  let find = (key) => Js.Array.find((((key', _)) => key == key'), params)
  switch (find("worker"), find("image")) {
    | (Some((_, worker)), Some((_, image))) => Some((worker, image))
    | _ => None
  }
}

let route = (url: RescriptReactRouter.url) => {
  let worker = getWorker(url.search)
  switch url.path {
  | list{} => Ok(Main)
  | list{orgName, repoName} =>
    Ok(Repo({repoId: orgName ++ "/" ++ repoName,
             benchmarkName: None,
             worker}))
  | list{orgName, repoName, "benchmark", benchmarkName} =>
    Ok(Repo({repoId: orgName ++ "/" ++ repoName,
             benchmarkName: Some(benchmarkName),
             worker}))
  | list{orgName, repoName, "pull", pullNumberStr} =>
    switch Belt.Int.fromString(pullNumberStr) {
    | Some(pullNumber) =>
      Ok(
        RepoPull({
          repoId: orgName ++ "/" ++ repoName,
          pullNumber: pullNumber,
          benchmarkName: None,
          worker
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
          worker
        }),
      )
    | None => Error({path: url.path, reason: "Invalid pull number: " ++ pullNumberStr})
    }
  | _ => Error({path: url.path, reason: "Unknown route: /" ++ String.concat("/", url.path)})
  }
}

let workerParams = (worker) =>
  switch worker {
    | None => ""
    | Some((worker, dockerImage)) =>
      "?worker=" ++ Js.Global.encodeURIComponent(worker) ++ "&image=" ++ Js.Global.encodeURIComponent(dockerImage)
  }

let path = route =>
  switch route {
  | Main => "/"
  | Repo({repoId, benchmarkName: None, worker}) => "/" ++ repoId ++ workerParams(worker)
  | Repo({repoId, benchmarkName: Some(benchmarkName), worker}) =>
    "/" ++ repoId ++ "/benchmark/" ++ benchmarkName ++ workerParams(worker)
  | RepoPull({repoId, pullNumber, benchmarkName: None, worker}) =>
    "/" ++ repoId ++ "/pull/" ++ Belt.Int.toString(pullNumber) ++ workerParams(worker)
  | RepoPull({repoId, pullNumber, benchmarkName: Some(benchmarkName), worker}) =>
    "/" ++ repoId ++ "/pull/" ++ Belt.Int.toString(pullNumber) ++ "/benchmark/" ++ benchmarkName
    ++ workerParams(worker)
  }

let useRoute = () => RescriptReactRouter.useUrl()->route

let go = route => RescriptReactRouter.push(path(route))
