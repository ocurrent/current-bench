type chart_spec = {
  title: string,
  yunit: string,
  xdata: array((string, int)),
};

module C3 = {
  module Value = {
    type t;
    external int: int => t = "%identity";
    external string: string => t = "%identity";
  };

  [@bs.deriving abstract]
  type tick = {
    [@bs.optional]
    values: array(string),
    [@bs.optional]
    rotate: int,
    [@bs.optional]
    fit: bool,
    [@bs.optional]
    multiline: bool,
  };

  [@bs.deriving abstract]
  type axis = {
    [@bs.as "type"]
    typ: string,
    [@bs.optional]
    tick,
    [@bs.optional]
    categories: array(string),
  };

  type axis_spec = {x: axis};

  [@bs.deriving abstract]
  type data = {
    columns: array(array(Value.t)),
    [@bs.optional]
    x: string,
  };

  [@bs.deriving abstract]
  type generateArg = {
    bindto: string,
    [@bs.optional]
    axis: axis_spec,
    data,
  };
};

[@ms.module "d3"] [@bs.module "c3"]
external generate: C3.generateArg => Js.t(unit) = "generate";

let rightButtonStyle =
  ReactDOMRe.Style.make(~borderRadius="0px 4px 4px 0px", ~width="48px", ());

let chart_of_spec = (id, {xdata, _}) => {
  let series =
    Array.append(
      C3.Value.([|string("data")|]),
      xdata |> Array.map(((_xlabel, datum)) => C3.Value.int(datum)),
    );
  let xlabels =
    xdata |> Array.map(((xlabel, _datum)) => Utils.short_hash(xlabel));
  C3.generateArg(
    ~bindto=Format.sprintf("#%s", id),
    ~axis={
      x:
        C3.axis(
          ~typ="category",
          ~categories=xlabels,
          ~tick=C3.tick(~rotate=-70, ~fit=true, ~multiline=false, ()),
          (),
        ),
    },
    ~data=C3.data(~columns=[|series|], ()),
    (),
  );
};

let uid: int => string =
  length => {
    let rand_chr = () =>
      switch (Random.int(26 + 26 + 10)) {
      | x when x < 10 => Char.chr(48 + x)
      | x when x - 10 < 26 => Char.chr(65 + (x - 10))
      | x => Char.chr(97 + (x - 36))
      };
    String.init(length, _i => rand_chr());
  };

[@react.component]
let make = (~spec) => {
  let id = Format.sprintf("chart-%s", uid(10));
  let {title, _} = spec;
  let chart = chart_of_spec(id, spec);
  Js.log(chart);
  <div className="container">
    <div className="containerTitle">
      <code> {React.string(title)} </code>
    </div>
    <div className="containerContent">
      <div
        style={ReactDOMRe.Style.make(
          ~display="flex",
          ~alignItems="center",
          ~justifyContent="space-between",
          (),
        )}
      />
    </div>
    <div id />
    <button
      style=rightButtonStyle
      onClick={_event => ignore(generate(chart): Js.t(unit))}>
      {React.string("Click me")}
    </button>
  </div>;
};
