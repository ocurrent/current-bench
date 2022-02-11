type t = {
  iat : int;
  (* Issued at time *)
  exp : int;
  (* JWT expiration time (10 minute maximum) *)
  iss : string; (* GitHub App's identifier *)
}
[@@deriving to_yojson]

let b64encode = Base64.(encode_exn ~pad:false ~alphabet:uri_safe_alphabet)
let header = b64encode {|{"typ":"JWT","alg":"RS256"}|} ^ "."

let encode ~key ~iat ~app_id =
  let exp = iat + (10 * 60) in
  let t = { iat; exp; iss = app_id } in
  let payload = to_yojson t |> Yojson.Safe.to_string |> b64encode in
  let data = header ^ payload in
  let signature =
    let msg = Cstruct.of_string data in
    Mirage_crypto_pk.Rsa.PKCS1.sign ~hash:`SHA256 ~key (`Message msg)
  in
  Printf.sprintf "%s.%s" data (b64encode (Cstruct.to_string signature))

let read_file path =
  let ch = open_in_bin path in
  Fun.protect
    (fun () ->
      let len = in_channel_length ch in
      really_input_string ch len)
    ~finally:(fun () -> close_in ch)

let key_of_file filename =
  let data = read_file filename in
  Mirage_crypto_rng_unix.initialize ();
  match X509.Private_key.decode_pem (Cstruct.of_string data) with
  | Error (`Msg msg) -> Fmt.failwith "Failed to parse secret key!@ %s" msg
  | Ok (`RSA key) -> key
  | Ok _ -> Fmt.failwith "Unsupported private key type"
  [@@warning "-11"]

let () =
  match Sys.argv with
  | [| _; app_id; key |] ->
      let iat = int_of_float (Unix.gettimeofday ()) - 60 in
      let key = key_of_file key in
      let token = encode ~key ~iat ~app_id in
      Printf.printf "%s\n%!" token
  | _ -> failwith "expected arguments <app_id> <public key file>"
