open Lwt.Syntax

let unique lst =
  List.fold_left (fun acc x -> if List.mem x acc then acc else x :: acc) [] lst

module Mstr = Map.Make (String)

let group fn lst =
  List.fold_left
    (fun acc elt ->
      let key, value = fn elt in
      let values = try Mstr.find key acc with Not_found -> [] in
      Mstr.add key (value :: values) acc)
    Mstr.empty lst

type config = { url : string; port : int }

module H = Tyxml.Html

let list_projects ~db () =
  let ps = Storage.get_projects ~db in
  H.ul
  @@ List.map (fun p -> H.li [ H.a ~a:[ H.a_href ("/" ^ p) ] [ H.txt p ] ])
  @@ List.sort String.compare
  @@ ps

let ocurrent_url =
  try Sys.getenv "OCAML_BENCH_PIPELINE_URL"
  with Not_found ->
    failwith "missing environment variable OCAML_BENCH_PIPELINE_URL"

let log_url ~job_id () = Printf.sprintf "%s/job/%s" ocurrent_url job_id
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

let list_commits ~db ~repo_id ~pr ~worker ~docker_image () =
  let commits = Storage.get_commits ~db ~repo_id ~pr in
  let envs =
    unique
    @@ List.map
         (fun (_, _, worker, docker_image, _, _) -> (worker, docker_image))
         commits
  in
  let commits =
    group
      (fun (hash, commit, worker, image, status, job_id) ->
        (hash, (commit, worker, image, status, job_id)))
      commits
  in
  let find key lst = List.find_opt (fun (_, w, i, _, _) -> (w, i) = key) lst in
  H.table
    (H.tr
       (H.th ~a:[ H.a_class [ "hash" ] ] [ H.txt "#" ]
       :: H.th ~a:[ H.a_class [ "commit" ] ] [ H.txt "Commit" ]
       :: List.map (th_env ~repo_id ~pr ~worker ~docker_image) envs)
    :: List.map
         (fun (hash, results) ->
           let msg, _, _, _, _ = List.hd results in
           H.tr
             (H.td [ H.txt (short_string hash) ]
             :: H.td [ H.txt msg ]
             :: List.map
                  (fun env ->
                    H.td
                      ~a:[ H.a_class (env_selected ~worker ~docker_image env) ]
                      [
                        (match find env results with
                        | None -> H.txt "---"
                        | Some (_, _, _, status, job_id) ->
                            H.a
                              ~a:[ H.a_href (log_url ~job_id ()) ]
                              [ H.txt status ]);
                      ])
                  envs))
         (Mstr.bindings commits))

let list_benchmarks ~db ~repo_id ~pr ~worker ~docker_image () =
  H.div
    [
      H.h2 [ H.txt "Commits:" ];
      list_commits ~db ~repo_id ~pr ~worker ~docker_image ();
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

let find key lst = List.find_opt (fun (w, i, _, _, _, _) -> (w, i) = key) lst

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
             (match find env columns with
             | None -> H.txt "---"
             | Some (w, i, _, run_at, status, _) ->
                 H.a
                   ~a:
                     [
                       H.a_href
                         (pr_url ~repo_id ~pr:(`PR pr) ~worker:w ~docker_image:i
                            ());
                     ]
                   [ H.txt status; H.txt " "; H.txt run_at ]);
           ])
       envs

let list_pr ~db ~repo_id ~worker ~docker_image () =
  let ps = Storage.get_prs ~db repo_id in
  let envs =
    unique
    @@ List.map
         (fun ((_, worker, docker_image), _, _, _, _) -> (worker, docker_image))
         ps
  in
  let ps =
    Mstr.bindings
    @@ group (fun ((pr, w, i), t, r, s, j) -> (pr, (w, i, t, r, s, j))) ps
  in
  let ps =
    List.sort
      (fun a b ->
        match (a, b) with
        | (_, (_, _, _, run_at, _, _) :: _), (_, (_, _, _, run_at', _, _) :: _)
          ->
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
                 | (_, _, title, _, _, _) :: _ -> title
                 | [] -> assert false
               in
               H.tr
                 (pr_link ~repo_id ~worker ~docker_image ~pr ~title ~columns
                    ~envs))
             ps);
      list_benchmarks ~db ~repo_id ~pr:`Branch ~worker ~docker_image ();
    ]

let header ~request =
  H.div
    ~a:[ H.a_id "header" ]
    [
      H.a ~a:[ H.a_href "/" ] [ H.txt "current-bench" ];
      (match Dream.param request "owner" with
      | owner -> H.a ~a:[ H.a_href ("/" ^ owner) ] [ H.txt owner ]
      | exception _ -> H.txt "");
      (match (Dream.param request "owner", Dream.param request "repo") with
      | owner, repo ->
          H.a ~a:[ H.a_href ("/" ^ owner ^ "/" ^ repo) ] [ H.txt repo ]
      | exception _ -> H.txt "");
    ]

let template ~request body =
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
  @@ H.body [ header ~request; H.div ~a:[] [ body ] ]

let string_of_tyxml html = Format.asprintf "%a" (Tyxml.Html.pp ()) html

let get_worker ~db ~repo_id ~pr request =
  let worker = Dream.query request "worker" in
  let docker_image = Dream.query request "docker_image" in
  let candidates = Storage.get_workers ~db ~repo_id ~pr in
  match (worker, docker_image, candidates) with
  | Some w, Some i, _ when List.mem (w, i) candidates -> (w, i)
  | _, _, [] -> (Config.default_worker, Config.default_docker)
  | _, _, wi :: _ -> wi

let html ~request body =
  Dream.html (string_of_tyxml (template ~request (body ())))

let main ~front ~db =
  Dream.serve ~port:front.port ~interface:"0.0.0.0"
  @@ Dream.logger
  @@ Dream.router
       [
         Dream.get "/_static/**" (Dream.static "/mnt/project/static");
         Dream.get "/" (fun request -> html ~request (list_projects ~db));
         Dream.get "/:owner" (fun request ->
             let owner = Dream.param request "owner" in
             html ~request (list_repos ~db ~owner));
         Dream.get "/:owner/:repo" (fun request ->
             let owner = Dream.param request "owner" in
             let repo = Dream.param request "repo" in
             let repo_id = owner ^ "/" ^ repo in
             let worker, docker_image =
               get_worker ~db ~repo_id ~pr:`Branch request
             in
             Printf.printf "\n\nworker = %S, image = %S\n\n\n%!" worker
               docker_image;
             html ~request (list_pr ~db ~repo_id ~worker ~docker_image));
         Dream.get "/:owner/:repo/pull/:pr" (fun request ->
             let owner = Dream.param request "owner" in
             let repo = Dream.param request "repo" in
             let repo_id = owner ^ "/" ^ repo in
             let pr = `PR (Dream.param request "pr") in
             let worker, docker_image = get_worker ~db ~repo_id ~pr request in
             html ~request
               (list_benchmarks ~db ~repo_id ~pr ~worker ~docker_image));
       ]

let main ~front ~db =
  let+ () = main ~front ~db in
  Error (`Msg "Frontend was terminated?")
