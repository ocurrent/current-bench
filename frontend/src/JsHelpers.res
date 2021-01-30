let jsDictToMap = (dict: Js.Dict.t<'a>): Belt.Map.String.t<'a> => {
  Belt.Map.String.fromArray(Js.Dict.entries(dict))
}
