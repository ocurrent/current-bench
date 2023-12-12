type worker = option<(string, string)>
type dateRange = option<(string, string)>

type route =
  | Main
  | Repo({repoId: string, benchmarkName: option<string>, worker: worker, dateRange: dateRange})
  | RepoPull({
      repoId: string,
      pullNumber: int,
      pullBase: string,
      benchmarkName: option<string>,
      worker: worker,
      dateRange: dateRange,
    })
  | RepoBranch({
      repoId: string,
      branch: string,
      benchmarkName: option<string>,
      worker: worker,
      dateRange: dateRange,
    })

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

let getWorker = query => {
  let params = parseParams(query)
  let find = key => Js.Array.find(((key', _)) => key == key', params)
  switch (find("worker"), find("image")) {
  | (Some((_, worker)), Some((_, image))) => Some((worker, image))
  | _ => None
  }
}

let getDateRange = query => {
  let params = parseParams(query)
  let find = key => Js.Array.find(((key', _)) => key == key', params)
  switch (find("start"), find("end")) {
  | (Some((_, start)), Some((_, end))) => Some((start, end))
  | _ => None
  }
}

let route = (url: RescriptReactRouter.url) => {
  let worker = getWorker(url.search)
  let dateRange = getDateRange(url.search)
  switch url.path {
  | list{} => Ok(Main)
  | list{orgName, repoName} =>
    Ok(
      Repo({
        repoId: orgName ++ "/" ++ repoName,
        benchmarkName: None,
        worker,
        dateRange,
      }),
    )
  | list{orgName, repoName, "benchmark", benchmarkName} =>
    Ok(
      Repo({
        repoId: orgName ++ "/" ++ repoName,
        benchmarkName: Some(benchmarkName),
        worker,
        dateRange,
      }),
    )
  | list{orgName, repoName, "branch", branchName} =>
    Ok(
      RepoBranch({
        repoId: orgName ++ "/" ++ repoName,
        branch: branchName,
        benchmarkName: None,
        worker,
        dateRange,
      }),
    )
  | list{orgName, repoName, "branch", branchName, "benchmark", benchmarkName} =>
    Ok(
      RepoBranch({
        repoId: orgName ++ "/" ++ repoName,
        branch: branchName,
        benchmarkName: Some(benchmarkName),
        worker,
        dateRange,
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
          dateRange,
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
          dateRange,
        }),
      )
    | None => Error({path: url.path, reason: "Invalid pull number: " ++ pullNumberStr})
    }
  | _ => Error({path: url.path, reason: "Unknown route: /" ++ String.concat("/", url.path)})
  }
}

let makeQueryParams = (worker, dateRange) => {
  switch (worker, dateRange) {
  | (Some((worker, dockerImage)), Some((start, end))) =>
    "?worker=" ++
    Js.Global.encodeURIComponent(worker) ++
    "&image=" ++
    Js.Global.encodeURIComponent(dockerImage) ++
    "&start=" ++
    Js.Global.encodeURIComponent(start) ++
    "&end=" ++
    Js.Global.encodeURIComponent(end)
  | (Some((worker, dockerImage)), None) =>
    "?worker=" ++
    Js.Global.encodeURIComponent(worker) ++
    "&image=" ++
    Js.Global.encodeURIComponent(dockerImage)
  | (None, Some((start, end))) =>
    "?start=" ++ Js.Global.encodeURIComponent(start) ++ "&end=" ++ Js.Global.encodeURIComponent(end)
  | (None, None) => ""
  }
}

let path = route => {
  switch route {
  | Main => "/"
  | Repo({repoId, benchmarkName: None, worker, dateRange}) =>
    "/" ++ repoId ++ makeQueryParams(worker, dateRange)
  | Repo({repoId, benchmarkName: Some(benchmarkName), worker, dateRange}) =>
    "/" ++ repoId ++ "/benchmark/" ++ benchmarkName ++ makeQueryParams(worker, dateRange)
  | RepoPull({repoId, pullNumber, pullBase, benchmarkName: None, worker, dateRange}) =>
    "/" ++
    repoId ++
    "/pull/" ++
    Belt.Int.toString(pullNumber) ++
    "/base/" ++
    pullBase ++
    makeQueryParams(worker, dateRange)
  | RepoPull({
      repoId,
      pullNumber,
      pullBase,
      benchmarkName: Some(benchmarkName),
      worker,
      dateRange,
    }) =>
    "/" ++
    repoId ++
    "/pull/" ++
    Belt.Int.toString(pullNumber) ++
    "/base/" ++
    pullBase ++
    "/benchmark/" ++
    benchmarkName ++
    makeQueryParams(worker, dateRange)
  | RepoBranch({repoId, branch, benchmarkName: None, worker, dateRange}) =>
    "/" ++ repoId ++ "/branch/" ++ branch ++ makeQueryParams(worker, dateRange)
  | RepoBranch({repoId, branch, benchmarkName: Some(benchmarkName), worker, dateRange}) =>
    "/" ++
    repoId ++
    "/branch/" ++
    branch ++
    "/benchmark/" ++
    benchmarkName ++
    makeQueryParams(worker, dateRange)
  }
}

let useRoute = () => RescriptReactRouter.useUrl()->route

let go = route => RescriptReactRouter.push(path(route))
