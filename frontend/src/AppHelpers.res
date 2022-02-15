let commitUrl = (~repoId, commit) => `https://github.com/${repoId}/commit/${commit}`
let pullUrl = (~repoId, ~pull) => `https://github.com/${repoId}/pull/${pull}`
let goToCommitLink = (~repoId, commit) => {
  let openUrl: string => unit = %raw(`function (url) { window.open(url, "_blank") }`)
  openUrl(commitUrl(~repoId, commit))
}

let pipelineUrl: string = %raw(`import.meta.env.VITE_OCAML_BENCH_PIPELINE_URL`)
let jobUrl = (~jobId) => pipelineUrl ++ "/job/" ++ jobId
