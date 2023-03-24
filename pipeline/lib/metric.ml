module Github = Current_github

module MetricKey = struct
  type t = string * string * string

  let compare a b = Stdlib.compare a b
end

module BenchmarksData = Map.Make (MetricKey)

let change_threshold = 0.01

let parse_benchmark_data ~data =
  let metrics =
    Array.fold_left
      (fun acc datum ->
        match datum with
        | _commit, benchmark_name, test_name, metrics ->
            metrics
            |> List.fold_left
                 (fun acc ({ name; value; _ } : Cb_schema.S.metric) ->
                   let key = (benchmark_name, test_name, name) in
                   BenchmarksData.add key value acc)
                 acc)
      BenchmarksData.empty data
  in
  let commit =
    if Array.length data > 0
    then
      let commit, _, _, _ = data.(0) in
      Some commit
    else None
  in
  (metrics, commit)

let sum_float_list xs = List.fold_left (fun acc x -> acc +. x) 0. xs

let mean_float_list xs =
  let n = List.length xs in
  match n with 0 -> 0. | _ -> sum_float_list xs /. Float.of_int n

let avg_of_value (v : Cb_schema.S.value) =
  match v with
  | Float v -> v
  | Floats vs -> mean_float_list vs
  | Assoc vs -> (
      vs
      |> List.filter_map (function
           | key, value when key = "avg" -> Some value
           | _ -> None)
      |> function
      | [ avg ] -> avg
      | _ -> 0.)

let calc_diff v cv =
  if cv <> 0.
  then (v -. cv) /. cv *. 100.
  else if v <> 0.
  then (v -. cv) /. v *. 100.
  else 0.

type change = Change of float | New

let find_changed_metrics ~metrics ~compare_metrics =
  BenchmarksData.merge
    (fun _ (value : Cb_schema.S.value option)
         (compare_value : Cb_schema.S.value option) ->
      match (value, compare_value) with
      | Some value, Some compare_value ->
          let delta =
            calc_diff (avg_of_value value) (avg_of_value compare_value)
          in
          if Float.abs delta > change_threshold
          then Some (Change delta)
          else None
      | Some _, None -> Some New
      | _ -> None)
    metrics compare_metrics

module SeenBenchmarks = Set.Make (MetricKey)

let format_changes ~changes =
  let text_list, _ =
    BenchmarksData.fold
      (fun (bench_name, test_name, metric_name) change (acc, seen) ->
        let bench_key = (bench_name, "", "") in
        let test_key = (bench_name, test_name, "") in
        let bench_seen = SeenBenchmarks.mem bench_key seen in
        let test_seen = SeenBenchmarks.mem test_key seen in
        let entry, seen =
          match bench_seen with
          | false ->
              ( Fmt.str "\n\n## Benchmark: %s\n" bench_name,
                SeenBenchmarks.add bench_key seen )
          | true -> ("", seen)
        in
        let entry, seen =
          match test_seen with
          | false ->
              ( Fmt.str "%s\n### Test: %s\n" entry test_name,
                SeenBenchmarks.add test_key seen )
          | true -> (entry, seen)
        in
        let change =
          match change with
          | New -> Fmt.str "- %s is a new metric" metric_name
          | Change change -> Fmt.str "- %s changed by %.1f%%" metric_name change
        in
        let entry = Fmt.str "%s%s" entry change in
        (entry :: acc, seen))
      changes ([], SeenBenchmarks.empty)
  in
  String.concat "\n" (List.rev text_list)

let commit_url ~repo_id ~commit =
  let url = Fmt.str "https://github.com/%s/commit/%s" repo_id commit in
  let short_sha = String.sub commit 0 7 in
  Fmt.str "[%s](%s)" short_sha url

let pull_url ~repo_id ~pull_number =
  let url = Fmt.str "https://github.com/%s/pulls/%d" repo_id pull_number in
  let pull = Fmt.str "#%d" pull_number in
  Fmt.str "[%s](%s)" pull url

let benchmarks_url ~repo_id ~worker ~docker_image =
  let base_url = Repository.frontend_url () in
  Fmt.str "%s/%s?worker=%s&image=%s" base_url repo_id worker docker_image

let format_changes_message ~changes ~repository ~worker ~docker_image
    ~main_commit =
  let pull_number = Repository.pull_number repository |> Option.get in
  let commit = Repository.commit_hash repository in
  let repo_id = Repository.info repository in
  let main_commit = Option.value ~default:"Unknown hash" main_commit in
  let metrics_url = benchmarks_url ~repo_id ~worker ~docker_image in
  let header =
    Fmt.str
      "%s (%s) changes the [metrics](%s) as follows in comparison to `main` \
       (%s) when running on `%s (%s)`:"
      (pull_url ~repo_id ~pull_number)
      (commit_url ~repo_id ~commit)
      metrics_url
      (commit_url ~repo_id ~commit:main_commit)
      worker docker_image
  in
  Fmt.str "%s\n%s" header (format_changes ~changes)

let post_github_comment ~api ~repository ~pull_number ~text =
  let open Lwt.Infix in
  let repo_owner = Repository.owner repository in
  let repo_name = Repository.name repository in
  let variables =
    [
      ("owner", `String repo_owner);
      ("name", `String repo_name);
      ("pullNumber", `Int pull_number);
    ]
  in
  let query =
    {|
       query ($owner: String!, $name: String!, $pullNumber: Int!) {
         repository(owner: $owner, name: $name) {
           pullRequest(number: $pullNumber) {
             id
           }
         }
       }
     |}
  in
  let ( / ) a b = Yojson.Safe.Util.member b a in
  let prId =
    Github.Api.exec_graphql api query ~variables >|= fun json ->
    let open Yojson.Safe.Util in
    let repo = json / "data" / "repository" in
    let id = repo / "pullRequest" / "id" in
    id |> to_string
  in
  let _ =
    prId >|= fun id ->
    let variables = [ ("subjectId", `String id); ("body", `String text) ] in
    let mutation =
      {|
         mutation ($body: String!, $subjectId: ID!) {
           addComment(input:{body: $body, subjectId: $subjectId}) {
             commentEdge {
               node {
                 body
               }
             }
           }
         }
       |}
    in
    Github.Api.exec_graphql api mutation ~variables >|= fun json ->
    let open Yojson.Safe.Util in
    let body =
      json / "data" / "addComment" / "commentEdge" / "node" / "body"
      |> to_string
    in
    print_endline @@ body
  in
  ()

module NotifyGithub = struct
  type t = {
    conninfo : string;
    repository : Repository.t;
    github_api : Github.Api.t option;
    worker : string;
    docker_image : string;
    pull_number : int;
  }

  let id = "notify-github"
  let pp h (key, _) = Fmt.pf h "notify-github %s" key

  module Key = struct
    type t = string

    let digest t : string = t
  end

  module Value = Current.Unit
  module Outcome = Current.String

  let auto_cancel = true

  let publish
      { conninfo; repository; worker; docker_image; github_api; pull_number; _ }
      job _worker_job_id () =
    let open Lwt.Infix in
    Current.Job.start job ~level:Current.Level.Above_average >>= fun () ->
    Logs.info (fun log -> log "Looking for significantly changed metrics...");
    match
      Storage.get_main_branch_metrics ~conninfo ~repository ~worker
        ~docker_image
    with
    | Some result_main, Some result -> (
        let compare_metrics, main_commit =
          parse_benchmark_data ~data:result_main
        in
        let metrics, _ = parse_benchmark_data ~data:result in
        let changes = find_changed_metrics ~metrics ~compare_metrics in
        match github_api with
        | Some api when not (BenchmarksData.is_empty changes) ->
            let text =
              format_changes_message ~changes ~repository ~worker ~docker_image
                ~main_commit
            in
            let () = post_github_comment ~api ~repository ~pull_number ~text in
            Lwt.return (Ok text)
        | Some _ -> Lwt.return (Ok "No changes found in metric comparison")
        | _ -> Lwt.return (Ok "No Github API configuration found"))
    | _ -> Lwt.return (Ok "No results found for comparison")
end

module NGC = Current_cache.Output (NotifyGithub)

let notify ~conninfo ~repository ~worker ~docker_image ~pull_number job_id =
  let open Current.Syntax in
  Current.component "notify-github"
  |> let> job_id = job_id in
     let github_api = Repository.github_api repository in
     NGC.set
       { conninfo; repository; github_api; worker; docker_image; pull_number }
       job_id ()

let notify_metric_changes ~conninfo ~repository ~worker ~docker_image ~config
    output =
  let repo_id = Repository.info repository in
  let commit_hash = Repository.commit_hash repository in
  let repo_configs = Config.find config repository in
  let should_notify =
    List.find_map
      (fun (repo_config : Config.repo) ->
        match repo_config.notify_github with
        | true
          when worker = repo_config.worker && docker_image = repo_config.image
          ->
            Some repo_config
        | _ -> None)
      repo_configs
  in
  let pull_number = Repository.pull_number repository in
  (* Use repo_info:commit_hash:worker:docker_image as job_id to prevent
     spamming PRs with metric change notifications *)
  let job_id_ = Fmt.str "%s:%s:%s:%s" repo_id commit_hash worker docker_image in
  match (pull_number, should_notify) with
  | Some pull_number, Some _ ->
      let job_id = Current.map (fun _ -> job_id_) output in
      notify ~conninfo ~repository ~worker ~docker_image ~pull_number job_id
  | None, _ -> Current.return "Not a pull request"
  | _, None ->
      Current.return @@ Fmt.str "GitHub notifications turned off for %s" job_id_
