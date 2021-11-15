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

type status = Fail | Pass | Running

let buildStatus = (lastCommitInfo: GetLastCommitInfo.t_lastCommitInfo, noCommitMetrics) => {
  if lastCommitInfo.failed->Belt.Option.getWithDefault(false) {
    Fail
  } else if noCommitMetrics {
    Running
  } else {
    Pass
  }
}

@react.component
let make = (~repoId, ~pullNumber=?, ~benchmarks: GetBenchmarks.t) => {
  let ({ReScriptUrql.Hooks.response: response}, _) = {
    ReScriptUrql.Hooks.useQuery(
      ~query=module(GetLastCommitInfo),
      makeGetLastCommitInfoVariables(~repoId, ~pullNumber?, ()),
    )
  }

  switch response {
  | Empty => <div> {"Something went wrong!"->Rx.text} </div>
  | Error({networkError: Some(_)}) => <div> {"Network Error"->Rx.text} </div>
  | Error({networkError: None}) => <div> {"Unknown Error"->Rx.text} </div>
  | Fetching => Rx.text("Loading...")
  | Data({lastCommitInfo: []})
  | PartialData({lastCommitInfo: []}, _) => Rx.null
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
    let status = buildStatus(lastCommitInfo, noCommitMetrics)
    <>
      <Row sx=containerSx spacing=#between alignY=#bottom>
        <Column spacing=Sx.sm>
          <Text sx=[Sx.text.bold, Sx.text.xs, Sx.text.color(Sx.gray700)]> "Last Commit" </Text>
          {renderCommitLink(repoId, lastCommitInfo.commit)}
        </Column>
        <Column spacing=Sx.sm>
          <Text sx=[Sx.text.bold, Sx.text.xs, Sx.text.color(Sx.gray700)]> "Build logs" </Text>
          {switch lastCommitInfo.build_job_id {
          | Some(jobId) => renderJobIdLink(jobId)
          | None =>
            <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.gray700)]> "No data" </Text>
          }}
        </Column>
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
          | Pass =>
            <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.green300)]> "Passed" </Text>
          | Running =>
            <Text sx=[Sx.text.bold, Sx.text.lg, Sx.text.color(Sx.yellow600)]> "Running" </Text>
          }}
        </Column>
      </Row>
      {switch status {
      | Fail
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
