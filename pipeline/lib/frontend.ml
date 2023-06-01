open Lwt.Syntax

let unique lst =
  List.fold_left (fun acc x -> if List.mem x acc then acc else x :: acc) [] lst

module String_map = Map.Make (String)

let group fn lst =
  List.fold_left
    (fun set elt ->
      let key, value = fn elt in
      let values = try String_map.find key set with Not_found -> [] in
      String_map.add key (value :: values) set)
    String_map.empty lst

type config = { url : string; port : int }

module H = Tyxml.Html

let list_projects ~db () =
  Storage.get_projects ~db
  |> List.sort String.compare
  |> List.map (fun p ->
         H.li [ H.a ~a:[ H.a_href ("/" ^ p) ] [ H.h2 [ H.txt p ] ] ])
  |> H.ul

let ocurrent_url =
  try Sys.getenv "OCAML_BENCH_PIPELINE_URL"
  with Not_found ->
    failwith "missing environment variable OCAML_BENCH_PIPELINE_URL"

let log_url ~run_job_id () = Printf.sprintf "%s/job/%s" ocurrent_url run_job_id
let short_string s = try String.sub s 0 6 with _ -> s

let pr_url ~repo_id ~pr ?worker ?docker_image () =
  let args =
    match (worker, docker_image) with
    | Some w, Some d -> Printf.sprintf "?worker=%s&docker_image=%s" w d
    | _ -> ""
  in
  let branch = match pr with `Branch -> "" | `PR p -> "/pull/" ^ p in
  String.concat "" [ "/"; repo_id; branch; args ]

let env_selected ~worker ~docker_image (w, i) =
  if (worker, docker_image) = (w, i) then [ "selected" ] else []

let th_env ~repo_id ~pr ~worker ~docker_image (w, i) =
  H.th
    ~a:[ H.a_class ("env" :: env_selected ~worker ~docker_image (w, i)) ]
    [
      H.a
        ~a:[ H.a_href (pr_url ~repo_id ~pr ~worker:w ~docker_image:i ()) ]
        [ H.txt @@ Printf.sprintf "%s (%s)" i w ];
    ]

let find_commit key lst =
  List.find_opt
    (fun (meta : Storage.commit_metadata) ->
      (meta.worker, meta.docker_image) = key)
    lst

let find_pr key lst =
  List.find_opt
    (fun (meta : Storage.pr_metadata) -> (meta.worker, meta.docker_image) = key)
    lst

let list_commits ?owner ?repo ~db ~repo_id ~pr ~worker ~docker_image () =
  let commits = Storage.get_commits ~db ~repo_id ~pr in
  let envs =
    unique
    @@ List.map
         (fun (meta : Storage.commit_metadata) ->
           (meta.worker, meta.docker_image))
         commits
  in
  let commits =
    group
      (fun (meta : Storage.commit_metadata) -> (meta.commit_info.hash, meta))
      commits
  in
  H.table
    (H.tr
       (H.th ~a:[ H.a_class [ "hash" ] ] [ H.txt "#" ]
       :: H.th ~a:[ H.a_class [ "commit" ] ] [ H.txt "Commit" ]
       :: List.map (th_env ~repo_id ~pr ~worker ~docker_image) envs)
    :: List.map
         (fun (hash, results) ->
           let { Storage.commit_info = { message; _ }; _ } = List.hd results in
           H.tr
             (H.td
                [
                  H.a
                    ~a:
                      (match (owner, repo) with
                      | Some owner, Some repo ->
                          [
                            H.a_href
                              (* FIXME: we assume github here *)
                              (Printf.sprintf "https://github.com/%s/%s/%s"
                                 owner repo hash);
                          ]
                      | _ -> [])
                    [ H.txt (short_string hash) ];
                ]
             :: H.td [ H.txt message ]
             :: List.map
                  (fun env ->
                    H.td
                      ~a:[ H.a_class (env_selected ~worker ~docker_image env) ]
                      [
                        (match find_commit env results with
                        | None -> H.txt "---"
                        | Some { Storage.status; run_job_id; _ } ->
                            H.a
                              ~a:[ H.a_href (log_url ~run_job_id ()) ]
                              [ H.txt (Storage.string_of_status status) ]);
                      ])
                  envs))
         (String_map.bindings commits))

let list_benchmarks ?owner ?repo ~db ~repo_id ~pr ~worker ~docker_image () =
  H.div
    [
      H.h2 [ H.txt "Commits:" ];
      list_commits ?owner ?repo ~db ~repo_id ~pr ~worker ~docker_image ();
      Plot.plot ~db ~repo_id ~pr ~worker ~docker_image;
    ]

let list_repos ~db ~owner () =
  let ps = Storage.get_repos ~db ~owner in
  H.div
    [
      H.ul
      @@ List.map (fun repo_id ->
             H.li [ H.a ~a:[ H.a_href ("/" ^ repo_id) ] [ H.txt repo_id ] ])
      @@ List.sort String.compare
      @@ ps;
    ]

let pr_link ~repo_id ~worker ~docker_image ~pr ~title ~columns ~envs =
  H.td
    [
      H.a
        ~a:[ H.a_href (pr_url ~repo_id ~pr:(`PR pr) ~worker ~docker_image ()) ]
        [ H.txt ("PR#" ^ pr ^ " " ^ title) ];
    ]
  :: List.map
       (fun env ->
         H.td
           ~a:[ H.a_class (env_selected ~worker ~docker_image env) ]
           [
             (match find_pr env columns with
             | None -> H.txt "---"
             | Some { Storage.worker; docker_image; run_at; status; _ } ->
                 H.a
                   ~a:
                     [
                       H.a_href
                         (pr_url ~repo_id ~pr:(`PR pr) ~worker ~docker_image ());
                     ]
                   [
                     H.txt (Storage.string_of_status status);
                     H.txt " ";
                     H.txt run_at;
                   ]);
           ])
       envs

let list_pr ?owner ?repo ~db ~repo_id ~worker ~docker_image () =
  let ps = Storage.get_prs ~db repo_id in
  let envs =
    unique
    @@ List.map
         (fun (meta : Storage.pr_metadata) -> (meta.worker, meta.docker_image))
         ps
  in
  let ps =
    String_map.bindings
    @@ group
         (fun ({ Storage.pull_number; _ } as p) ->
           let pr_str =
             match pull_number with
             | Some n -> string_of_int n
             | None -> "FIXME: what text here?"
           in
           (pr_str, p))
         ps
  in
  let ps =
    List.sort
      (fun a b ->
        match (a, b) with
        | ( (_, { Storage.run_at; _ } :: _),
            (_, { Storage.run_at = run_at'; _ } :: _) ) ->
            -String.compare run_at run_at'
        | _ -> assert false)
      ps
  in
  H.div
    [
      H.table
        (H.tr
           (H.th [ H.txt "PR" ]
           :: List.map (th_env ~repo_id ~pr:`Branch ~worker ~docker_image) envs
           )
        :: List.map
             (fun (pr, columns) ->
               let title =
                 match columns with
                 | { Storage.title; _ } :: _ -> title
                 | [] -> assert false
               in
               H.tr
                 (pr_link ~repo_id ~worker ~docker_image ~pr ~title ~columns
                    ~envs))
             ps);
      list_benchmarks ?owner ?repo ~db ~repo_id ~pr:`Branch ~worker
        ~docker_image ();
    ]

let template ?owner ?repo body =
  let header =
    H.div
      ~a:[ H.a_id "header" ]
      [
        H.a ~a:[ H.a_href "/" ] [ H.txt "current-bench" ];
        (match owner with
        | Some owner -> H.a ~a:[ H.a_href ("/" ^ owner) ] [ H.txt owner ]
        | None -> H.txt "");
        (match (owner, repo) with
        | Some owner, Some repo ->
            H.a ~a:[ H.a_href ("/" ^ owner ^ "/" ^ repo) ] [ H.txt repo ]
        | _ -> H.txt "");
      ]
  in
  H.html
    ~a:[ H.a_lang "en" ]
    (H.head
       (H.title (H.txt "current-bench"))
       [
         H.meta ~a:[ H.a_charset "UTF-8" ] ();
         H.meta
           ~a:
             [
               H.a_name "viewport";
               H.a_content "width=device-width, initial-scale=1";
             ]
           ();
         H.script
           ~a:
             [
               H.a_defer ();
               H.a_src "https://cdn.plot.ly/plotly-basic-2.12.1.min.js";
             ]
           (H.txt "");
         H.script ~a:[ H.a_defer (); H.a_src "/_static/plot.js" ] (H.txt "");
         H.link ~rel:[ `Stylesheet ] ~href:"/_static/style.css" ();
       ])
  @@ H.body [ header; H.div ~a:[] [ body ] ]

let string_of_tyxml html = Format.asprintf "%a" (Tyxml.Html.pp ()) html

let get_worker ~db ~repo_id ~pr ~request =
  let worker = Dream.query request "worker" in
  let docker_image = Dream.query request "docker_image" in
  let candidates = Storage.get_workers ~db ~repo_id ~pr in
  match (worker, docker_image, candidates) with
  | Some w, Some i, _ when List.mem (w, i) candidates -> (w, i)
  | _, _, [] -> (Config.default_worker, Config.default_docker)
  | _, _, wi :: _ -> wi

let html ?owner ?repo body =
  Dream.html (string_of_tyxml (template ?owner ?repo (body ())))

let main ~front ~db =
  Dream.serve ~port:front.port ~interface:"0.0.0.0"
  @@ Dream.logger
  @@ Dream.router
       [
         Dream.get "/_static/**" (Dream.static "/mnt/project/static");
         Dream.get "/" (fun _ -> html (list_projects ~db));
         Dream.get "/:owner" (fun request ->
             let owner = Dream.param request "owner" in
             html ~owner (list_repos ~db ~owner));
         Dream.get "/:owner/:repo" (fun request ->
             let owner = Dream.param request "owner" in
             let repo = Dream.param request "repo" in
             let repo_id = owner ^ "/" ^ repo in
             let worker, docker_image =
               get_worker ~db ~repo_id ~pr:`Branch ~request
             in
             html ~owner ~repo
               (list_pr ~owner ~repo ~db ~repo_id ~worker ~docker_image));
         Dream.get "/:owner/:repo/pull/:pr" (fun request ->
             let owner = Dream.param request "owner" in
             let repo = Dream.param request "repo" in
             let repo_id = owner ^ "/" ^ repo in
             let pr = `PR (Dream.param request "pr") in
             let worker, docker_image = get_worker ~db ~repo_id ~pr ~request in
             html
               (list_benchmarks ~owner ~repo ~db ~repo_id ~pr ~worker
                  ~docker_image));
       ]

let main ~front ~db =
  let+ () = main ~front ~db in
  Error (`Msg "Frontend was terminated?")
