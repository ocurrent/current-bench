let commitUrl = (~repoId, commit) => `https://github.com/${repoId}/commit/${commit}`
let goToCommitLink = (~repoId, commit) => {
  let openUrl: string => unit = %raw(`function (url) { window.open(url, "_blank") }`)
  openUrl(commitUrl(~repoId, commit))
}
