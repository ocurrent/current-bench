let commitUrl = (~repoId, commit) => `https://github.com/${repoId}/commit/${commit}`
let pullUrl = (~repoId, ~pull) => `https://github.com/${repoId}/pull/${pull}`
let goToCommitLink = (~repoId, commit) => {
  let openUrl: string => unit = %raw(`function (url) { window.open(url, "_blank") }`)
  openUrl(commitUrl(~repoId, commit))
}

let pipelineUrl: string = %raw(`import.meta.env.VITE_OCAML_BENCH_PIPELINE_URL`)
let jobUrl = (~lines=?, jobId) => {
  let href = pipelineUrl ++ "/job/" ++ jobId
  switch lines {
  | Some(start, end) => href ++ `#L${Belt.Int.toString(start)}-L${Belt.Int.toString(end)}`
  | _ => href
  }
}

let defaultBenchmarkName = "default"
