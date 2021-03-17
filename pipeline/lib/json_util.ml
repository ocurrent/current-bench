let stream_to_list stream =
  let acc = ref [] in
  Stream.iter (fun x -> acc := x :: !acc) stream;
  List.rev !acc

let parse_many string = stream_to_list (Yojson.Safe.stream_from_string string)
