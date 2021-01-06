let jsonFieldExn = (type a, json, field, kind: Js.Json.kind<a>): a => {
  open Belt
  let x = json->Js.Json.decodeObject->Option.getExn->Js.Dict.get(field)->Option.getExn
  switch kind {
  | Js.Json.String => Js.Json.decodeString(x)->Option.getExn
  | Js.Json.Number => Js.Json.decodeNumber(x)->Option.getExn
  | Js.Json.Object => Js.Json.decodeObject(x)->Option.getExn
  | Js.Json.Array => Js.Json.decodeArray(x)->Option.getExn
  | Js.Json.Boolean => Js.Json.decodeBoolean(x)->Option.getExn
  | Js.Json.Null => (Obj.magic(Js.Json.decodeNull(x)->Option.getExn): Js.Types.null_val)
  }
}
