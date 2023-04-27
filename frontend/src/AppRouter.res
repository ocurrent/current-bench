type worker = option<(string, string)>

type route =
  | Main
  | Repo({repoId: string, benchmarkName: option<string>, worker: worker})
  | RepoPull({
      repoId: string,
      pullNumber: int,
      pullBase: string,
      benchmarkName: option<string>,
      worker: worker,
    })
  | RepoBranch({repoId: string, branch: string, benchmarkName: option<string>, worker: worker})

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
    Ok(
      Repo({
        repoId: orgName ++ "/" ++ repoName,
        benchmarkName: Some(benchmarkName),
        worker,
      }),
    )
  | list{orgName, repoName, "branch", branchName} =>
    Ok(
      RepoBranch({
        repoId: orgName ++ "/" ++ repoName,
        branch: branchName,
        benchmarkName: None,
        worker,
      }),
    )
  | list{orgName, repoName, "branch", branchName, "benchmark", benchmarkName} =>
    Ok(
      RepoBranch({
        repoId: orgName ++ "/" ++ repoName,
        branch: branchName,
        benchmarkName: Some(benchmarkName),
        worker,
      }),
    )
  | list{orgName, repoName, "pull", pullNumberStr, "base", pullBase} =>
    switch Belt.Int.fromString(pullNumberStr) {
    | Some(pullNumber) =>
      Ok(
        RepoPull({
          repoId: orgName ++ "/" ++ repoName,
          pullNumber,
          pullBase,
          benchmarkName: None,
          worker,
        }),
      )
    | None => Error({path: url.path, reason: "Invalid pull number: " ++ pullNumberStr})
    }
  | list{orgName, repoName, "pull", pullNumberStr, "base", pullBase, "benchmark", benchmarkName} =>
    switch Belt.Int.fromString(pullNumberStr) {
    | Some(pullNumber) =>
      Ok(
        RepoPull({
          repoId: orgName ++ "/" ++ repoName,
          pullNumber,
          pullBase,
          benchmarkName: Some(benchmarkName),
          worker,
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
  | RepoPull({repoId, pullNumber, pullBase, benchmarkName: None, worker}) =>
    "/" ++
    repoId ++
    "/pull/" ++
    Belt.Int.toString(pullNumber) ++
    "/base/" ++
    pullBase ++
    workerParams(worker)
  | RepoPull({repoId, pullNumber, pullBase, benchmarkName: Some(benchmarkName), worker}) =>
    "/" ++
    repoId ++
    "/pull/" ++
    Belt.Int.toString(pullNumber) ++
    "/base/" ++
    pullBase ++
    "/benchmark/" ++
    benchmarkName ++
    workerParams(worker)
  | RepoBranch({repoId, branch, benchmarkName: None, worker}) =>
    "/" ++ repoId ++ "/branch/" ++ branch ++ workerParams(worker)
  | RepoBranch({repoId, branch, benchmarkName: Some(benchmarkName), worker}) =>
    "/" ++ repoId ++ "/branch/" ++ branch ++ "/benchmark/" ++ benchmarkName ++ workerParams(worker)
  }

let useRoute = () => RescriptReactRouter.useUrl()->route

let go = route => RescriptReactRouter.push(path(route))
