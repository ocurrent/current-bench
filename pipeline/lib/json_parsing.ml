let is_whitespace = function '\n' | ' ' | '\t' | '\r' -> true | _ -> false

type automata =
  | BeforeID  (** Curly brace received, waiting for a string id *)
  | InArray  (** Waiting for a value or a \] *)
  | InString  (** Inside the identifier: "foo" *)
  | Escaped  (** Right after a \ inside a string *)
  | AfterID  (** After string, waiting for a colon *)
  | BeforeValue  (** After colon, waiting for any value on the right side *)
  | AfterValue  (** After value, waiting for a comma or closing bracket *)
  | Number of num_state
  | Bool of bool_state
  | Null of null_state

and num_state =
  | Sign (* After receiving a '-' sign *)
  | LeadZero (* After receiving a leading 0 *)
  | Num (* Standard numbers *)
  | FracDot (* Received a '.' starting a decimal *)
  | FracNum (* Decimals *)
  | ExpE (* Received exponent 'e' *)
  | ExpSign (* Received exponent sign *)
  | ExpNum (* Exponents *)

and bool_state = BT | BR | BU | BF | BA | BL | BS
and null_state = NN | NU | NL

exception Finished_JSON
exception Invalid_JSON

let json_step_aux stack chr =
  if is_whitespace chr
  then stack
  else
    match (stack, chr) with
    (* Initial state *)
    | [], '{' -> [ BeforeID ]
    | [], _ -> []
    (* Bracket open or after a comma *)
    | BeforeID :: st, '"' -> InString :: AfterID :: st
    | [ BeforeID ], '}' -> raise Finished_JSON
    | BeforeID :: st, '}' -> st
    | BeforeID :: _, _ -> raise Invalid_JSON
    (* Inside string *)
    | InString :: _, '\\' -> Escaped :: stack
    | Escaped :: st, _ -> st
    | InString :: st, '"' -> st
    | InString :: _, _ -> stack
    (* After string *)
    | AfterID :: st, ':' -> BeforeValue :: st
    | AfterID :: _, _ -> raise Invalid_JSON
    (* After value *)
    | AfterValue :: InArray :: st, ']' -> AfterValue :: st
    | AfterValue :: InArray :: st, ',' -> BeforeValue :: InArray :: st
    | AfterValue :: InArray :: _, _ -> raise Invalid_JSON
    | [ AfterValue ], '}' -> raise Finished_JSON
    | AfterValue :: st, '}' -> st
    | AfterValue :: st, ',' -> BeforeID :: st
    | AfterValue :: _, _ -> raise Invalid_JSON
    (* Before value *)
    | BeforeValue :: st, '"' -> InString :: AfterValue :: st
    | BeforeValue :: st, '{' -> BeforeID :: AfterValue :: st
    (*     Booleans + null *)
    | BeforeValue :: st, 't' -> Bool BT :: st
    | Bool BT :: st, 'r' -> Bool BR :: st
    | Bool BR :: st, 'u' -> Bool BU :: st
    | Bool BU :: st, 'e' -> AfterValue :: st
    | BeforeValue :: st, 'f' -> Bool BF :: st
    | Bool BF :: st, 'a' -> Bool BA :: st
    | Bool BA :: st, 'l' -> Bool BL :: st
    | Bool BL :: st, 's' -> Bool BS :: st
    | Bool BS :: st, 'e' -> AfterValue :: st
    | BeforeValue :: st, 'n' -> Null NN :: st
    | Null NN :: st, 'u' -> Null NU :: st
    | Null NU :: st, 'l' -> Null NL :: st
    | Null NL :: st, 'l' -> AfterValue :: st
    | Bool BT :: _, _
    | Bool BR :: _, _
    | Bool BU :: _, _
    | Bool BF :: _, _
    | Bool BA :: _, _
    | Bool BL :: _, _
    | Bool BS :: _, _
    | Null NN :: _, _
    | Null NU :: _, _
    | Null NL :: _, _ ->
        raise Invalid_JSON
    (*     Arrays *)
    | BeforeValue :: st, '[' -> BeforeValue :: InArray :: st
    | BeforeValue :: InArray :: st, ']' -> AfterValue :: st
    (*     Impossible case *)
    | InArray :: _, _ -> failwith "InArray shouldn't be on top of the stack"
    (*     Numbers *)
    | BeforeValue :: st, '-' -> Number Sign :: st
    | (BeforeValue | Number Sign) :: st, '0' -> Number LeadZero :: st
    | (BeforeValue | Number Sign) :: st, '1' .. '9' -> Number Num :: st
    | Number Num :: _, '0' .. '9' -> stack
    | Number (LeadZero | Num) :: st, '.' -> Number FracDot :: st
    | Number (FracDot | FracNum) :: st, '0' .. '9' -> Number FracNum :: st
    | Number (LeadZero | Num | FracNum) :: st, ('e' | 'E') -> Number ExpE :: st
    | Number ExpE :: st, ('+' | '-') -> Number ExpSign :: st
    | Number (ExpE | ExpSign | ExpNum) :: st, '0' .. '9' -> Number ExpNum :: st
    (*         Finishing a number *)
    | Number (LeadZero | Num | FracNum | ExpNum) :: InArray :: st, ']' ->
        AfterValue :: st
    | Number (LeadZero | Num | FracNum | ExpNum) :: InArray :: st, ',' ->
        BeforeValue :: InArray :: st
    | [ Number (LeadZero | Num | FracNum | ExpNum) ], '}' -> raise Finished_JSON
    | Number (LeadZero | Num | FracNum | ExpNum) :: st, '}' -> st
    | Number (LeadZero | Num | FracNum | ExpNum) :: st, ',' -> BeforeID :: st
    (* Invalid states *)
    | (BeforeValue | Number _) :: _, _ -> raise Invalid_JSON

type json_parser = {
  current : Buffer.t;
  stack : automata list;
  lines : int;
  start_line : int;
  carriage_seen : bool;
}

let make_parser ?(lines = 1) ?(start_line = 1) () =
  {
    current = Buffer.create 16;
    stack = [];
    lines;
    start_line;
    carriage_seen = false;
  }

let json_step state chr =
  let state =
    match (chr, state.carriage_seen) with
    | '\r', _ -> { state with lines = state.lines + 1; carriage_seen = true }
    | '\n', false -> { state with lines = state.lines + 1 }
    | _ -> { state with carriage_seen = false }
  in
  match json_step_aux state.stack chr with
  | [] -> (None, { state with start_line = state.lines; stack = [] })
  | exception Invalid_JSON ->
      (None, make_parser ~lines:state.lines ~start_line:state.start_line ())
  | exception Finished_JSON ->
      Buffer.add_char state.current chr;
      let str = Buffer.contents state.current in
      (Some str, make_parser ~lines:state.lines ~start_line:state.start_line ())
  | hd :: _ as stack ->
      if hd = InString || (chr <> '\n' && chr <> '\r')
      then Buffer.add_char state.current chr;
      (None, { state with stack })

let steps (parsed, state) str =
  String.fold_left
    (fun (parsed, state) chr ->
      let opt_json, state = json_step state chr in
      let parsed =
        match opt_json with
        | Some json -> (json, (state.start_line, state.lines)) :: parsed
        | None -> parsed
      in
      (parsed, state))
    (parsed, state) str

let full str =
  let state = make_parser () in
  let parsed, _ = steps ([], state) str in
  parsed
