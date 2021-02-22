type route =
  | Main
  | Repo({repoId: string})
  | RepoPull({repoId: string, pullNumber: int})

type error = {
  path: list<string>,
  reason: string,
}

let route = (url: ReasonReactRouter.url) =>
  switch url.path {
  | list{} => Ok(Main)
  | list{orgName, repoName} => Ok(Repo({repoId: orgName ++ "/" ++ repoName}))
  | list{orgName, repoName, "pulls", pullNumberStr} =>
    switch Belt.Int.fromString(pullNumberStr) {
    | Some(pullNumber) => Ok(RepoPull({repoId: orgName ++ "/" ++ repoName, pullNumber: pullNumber}))
    | None => Error({path: url.path, reason: "Invalid pull number: " ++ pullNumberStr})
    }
  | _ => Error({path: url.path, reason: "Unknown route"})
  }

let path = route =>
  switch route {
  | Main => "/"
  | Repo({repoId}) => "/" ++ repoId
  | RepoPull({repoId, pullNumber}) => "/" ++ repoId ++ "/pulls/" ++ Belt.Int.toString(pullNumber)
  }

let useRoute = () => ReasonReactRouter.useUrl()->route

let go = route => ReasonReact.Router.push(path(route))
