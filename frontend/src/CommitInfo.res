open Components
open BenchmarkQueryHelpers

module GetLastCommitInfo = %graphql(`
query ($repoId: String!, $pullNumber: Int, $isMaster: Boolean!) {
  lastCommitInfo: benchmark_metadata(limit: 1, where: {_and: [{pull_number: {_eq: $pullNumber}}, {pull_number: {_is_null: $isMaster}}, {repo_id: {_eq: $repoId}}]}, order_by: [{run_at: desc_nulls_last}]) {
    run_at
    pull_number
    branch
    commit
    build_job_id
    run_job_id
    failed
    cancelled
    cancel_reason
    pr_title
  }
}
`)

let makeGetLastCommitInfoVariables = (
  ~repoId,
  ~pullNumber=?,
  (),
): GetLastCommitInfo.t_variables => {
  let isMaster = Belt.Option.isNone(pullNumber)
  {
    repoId: repoId,
    pullNumber: pullNumber,
    isMaster: isMaster,
  }
}

let containerSx = [
  Sx.w.full,
  Sx.border.xs,
  Sx.border.color(Sx.gray300),
  Sx.rounded.md,
  Sx.p.xl,
  Sx.mb.xl2,
]

let linkStyle = [Sx.text.bold, Sx.text.lg, Sx.p.zero]

let renderExternalLink = (~style=linkStyle, ~href, text) => {
  let sx = Array.concat(list{Link.sx_base, style})
  <a target="_blank" className={Sx.make(sx)} href> {Rx.text(text)} </a>
}

let url: string = %raw(`import.meta.env.VITE_OCAML_BENCH_PIPELINE_URL`)

let renderJobIdLink = jobId => {
  let shortJobId = switch String.split_on_char('/', jobId) {
  | list{_, shortJobId} => shortJobId
  | _ =>
    Js.log(("Error: invalid jobId", jobId))
    jobId
  }
  let href = url ++ "/job/" ++ jobId
  renderExternalLink(~href, shortJobId)
}

let renderCommitLink = (~style=linkStyle, repoId, commit) =>
  renderExternalLink(
    ~style,
    ~href=AppHelpers.commitUrl(~repoId, commit),
    DataHelpers.trimCommit(commit),
  )

type status = Cancel | Fail | Pass | Running

let buildStatus = (lastCommitInfo: GetLastCommitInfo.t_lastCommitInfo, noCommitMetrics) => {
  if lastCommitInfo.cancelled->Belt.Option.getWithDefault(false) {
    Cancel
  } else if lastCommitInfo.failed->Belt.Option.getWithDefault(false) {
    Fail
  } else if noCommitMetrics {
    Running
  } else {
    Pass
  }
}

@react.component
let make = (~repoId, ~pullNumber=?, ~benchmarks: GetBenchmarks.t, ~setOldMetrics) => {
  let ({ReScriptUrql.Hooks.response: response}, _) = {
    ReScriptUrql.Hooks.useQuery(
      ~query=module(GetLastCommitInfo),
      makeGetLastCommitInfoVariables(~repoId, ~pullNumber?, ()),
    )
  }

  // NOTE: This function needs to be called in all the branches of the switch,
  // if not we see a React Warning about a change in the order of Hooks called
  // by CommitInfo. (See https://reactjs.org/link/rules-of-hooks)
  let showingOldMetrics = flag => {
    // NOTE: We cannot directly call `setOldMetrics(_ => noCommitMetrics)` in
    // the success branch, since it is not recommended to update a component
    // (`App$BenchmarkView`) while rendering a different component
    // (`CommitInfo`). So, we wrap it in useEffect. (See
    // https://reactjs.org/link/setstate-in-render)
    React.useEffect(() => {
      setOldMetrics(_ => flag)
      None
    })
  }

  switch response {
  | Empty => {
      showingOldMetrics(false)
      <div> {"Something went wrong!"->Rx.text} </div>
    }
  | Error({networkError: Some(_)}) => {
      showingOldMetrics(false)
      <div> {"Network Error"->Rx.text} </div>
    }
  | Error({networkError: None}) => {
      showingOldMetrics(false)
      <div> {"Unknown Error"->Rx.text} </div>
    }
  | Fetching => {
      showingOldMetrics(false)
      Rx.text("Loading...")
    }
  | Data({lastCommitInfo: []})
  | PartialData({lastCommitInfo: []}, _) => {
      showingOldMetrics(false)
      Rx.null
    }
  | Data(data)
  | PartialData(data, _) =>
    let lastCommitInfo = data.lastCommitInfo[0]
    let lastBenchmark = Belt.Array.get(
      benchmarks.benchmarks,
      Belt.Array.length(benchmarks.benchmarks) - 1,
    )
    let noCommitMetrics = switch lastBenchmark {
    | None => true
    | Some(benchmark) => benchmark.commit != lastCommitInfo.commit
    }
    let sameBuildJobLog = switch (lastCommitInfo.build_job_id, lastCommitInfo.run_job_id) {
    | (Some(buildID), Some(jobID)) => buildID == jobID
    | (_, _) => false
    }
    showingOldMetrics(noCommitMetrics)
    let status = buildStatus(lastCommitInfo, noCommitMetrics)
    <>
      {switch lastCommitInfo.pull_number {
      | Some(pullNumber) => {
          let href = AppHelpers.pullUrl(~repoId, ~pull=string_of_int(pullNumber))
          <Row sx=containerSx spacing=#between alignY=#bottom>
            {renderExternalLink(~href, lastCommitInfo.pr_title->Belt.Option.getWithDefault("No PR Title"))}
          </Row>
        }
      | None => Rx.null
      }}
      <Row sx=containerSx spacing=#between alignY=#bottom>
        <Column spacing=Sx.sm>
          <Text sx=[Sx.text.bold, Sx.text.xs, Sx.text.color(Sx.gray700)]> "Last Commit" </Text>
          {renderCommitLink(repoId, lastCommitInfo.commit)}
        </Column>
        {switch sameBuildJobLog {
        | false =>
          <Column spacing=Sx.sm>
            <Text sx=[Sx.text.bold, Sx.text.xs, Sx.text.color(Sx.gray700)]> "Build logs" </Text>
            {switch lastCommitInfo.build_job_id {
            | Some(jobId) => renderJobIdLink(jobId)
            | None =>
              <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.gray700)]> "No data" </Text>
            }}
          </Column>
        | true => Rx.null
        }}
        <Column spacing=Sx.sm>
          <Text sx=[Sx.text.bold, Sx.text.xs, Sx.text.color(Sx.gray700)]> "Execution logs" </Text>
          {switch lastCommitInfo.run_job_id {
          | Some(jobId) => renderJobIdLink(jobId)
          | None =>
            <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.gray700)]> "No data" </Text>
          }}
        </Column>
        <Column spacing=Sx.sm>
          <Text sx=[Sx.text.bold, Sx.text.xs, Sx.text.color(Sx.gray700)]> "Status" </Text>
          {switch status {
          | Fail => <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.red300)]> "Failed" </Text>
          | Cancel =>
            <span>
              <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.gray900)]> "Cancelled" </Text>
              <Text sx=[Sx.text.blockDisplay, Sx.text.xs, Sx.text.color(Sx.gray600)]>
                {lastCommitInfo.cancel_reason->Belt.Option.getWithDefault("Unknown Reason")}
              </Text>
            </span>
          | Pass =>
            <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.green300)]> "Passed" </Text>
          | Running =>
            <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.yellow600)]> "Running" </Text>
          }}
        </Column>
      </Row>
      {switch status {
      | Fail
      | Cancel
      | Running =>
        switch lastBenchmark {
        | None => Rx.null
        | Some(benchmark) => <>
            <Text sx=[Sx.text.bold, Sx.text.xs, Sx.text.color(Sx.yellow600)]>
              "Metrics for an older commit "
            </Text>
            {renderCommitLink(
              ~style=[Sx.text.bold, Sx.text.xs, Sx.p.zero],
              repoId,
              benchmark.commit,
            )}
            <Text sx=[Sx.text.bold, Sx.text.xs, Sx.text.color(Sx.yellow600)]>
              " are shown below"
            </Text>
          </>
        }
      | _ => Rx.null
      }}
    </>
  }
}
