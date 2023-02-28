let trimCommit = commit => String.length(commit) > 7 ? String.sub(commit, 0, 7) : commit

let rec yojson_of_json = (json : Js.Json.t) : Json.t => {
  switch Js.Json.classify(json) {
    | JSONFalse => #Bool(false)
    | JSONTrue => #Bool(true)
    | JSONNull => #Null
    | JSONString(s) => #String(s)
    | JSONNumber(x) => #Float(x)
    | JSONArray(arr) =>
        #List(List.map(yojson_of_json, arr->Array.to_list))
    | JSONObject(dict) =>
        #Assoc(List.map(((key, val)) => { (key, yojson_of_json(val)) },
                        dict->Js.Dict.entries->Array.to_list))
  }
}
