type error = string

exception Error of error

let string_of_error e = e

type expect = Tuples_ok | Command_ok

type mock =
  | Expect_finish
  | Expect of (?expect:expect list -> string -> string array array)

module Mock = struct
  type t = mock

  module H = Hashtbl.Make (struct
    type t = string

    let equal = String.equal
    let hash = Hashtbl.hash
  end)

  let mocks : t list H.t = H.create 0
  let errors : exn H.t = H.create 0

  let catch ~conninfo fn =
    try fn ~conninfo
    with error when not (H.mem errors conninfo) ->
      (* remember only the first failure *)
      H.add errors conninfo error;
      raise error

  let unused_conninfo = "<db-not-used>"

  let uid () =
    let size = H.length mocks in
    string_of_int size

  let mock expected =
    let conninfo = uid () in
    H.add mocks conninfo expected;
    conninfo

  let pop ~conninfo =
    match H.find mocks conninfo with
    | mock :: rest ->
        H.replace mocks conninfo rest;
        mock
    | [] -> Alcotest.fail "Postgreql.Mock.with_mock: unexpected query"

  let with_mock expected fn =
    let conninfo = mock expected in
    Lwt.bind (fn ~conninfo) (fun result ->
        match H.find errors conninfo with
        | error -> raise error
        | exception Not_found -> (
            match H.find mocks conninfo with
            | [] -> Lwt.return result
            | remaining ->
                Alcotest.fail
                  (Printf.sprintf "Postgreql.Mock.with_mock: expected %i more"
                     (List.length remaining))))
end

let str_trim = Str.regexp "[\n ]+"
let str_timestamp = Str.regexp "to_timestamp([0-9.]+)"

let normalize query =
  query
  |> Str.global_replace str_trim " "
  |> Str.global_replace str_timestamp "to_timestamp(XXX)"
  |> String.trim

class connection ~conninfo () =
  object
    method exec ?expect query =
      Mock.catch ~conninfo @@ fun ~conninfo ->
      let query = normalize query in
      match Mock.pop ~conninfo with
      | Expect f ->
          let all = f ?expect query in
          object
            method get_all = all
          end
      | _ ->
          Alcotest.fail
            (Printf.sprintf "Postgreql.exec: unexpected exec %S" query)

    method finish =
      Mock.catch ~conninfo @@ fun ~conninfo ->
      match Mock.pop ~conninfo with
      | Expect_finish -> ()
      | _ -> Alcotest.fail "Postgreql.exec: unexpected finish"
  end
