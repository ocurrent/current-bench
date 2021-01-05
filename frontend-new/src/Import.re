let identity = x => x;


module Option = {
  type t('a) = option('a);

  let map = (f, self) =>
    switch (self) {
    | Some(x) => Some(f(x))
    | None => None
    };

  let bind = (f, self) =>
    switch (self) {
    | Some(x) => f(x)
    | None => None
    };

  let or_else = (f, self) =>
    switch (self) {
    | Some(x) => x
    | None => f()
    };

  let if_some = (f, self) =>
    switch (self) {
    | Some(x) => f(x)
    | None => ()
    };

  let if_none = (f, self) =>
    switch (self) {
    | Some(_) => ()
    | None => f()
    };

  let (<|>) = (opt1, opt2) =>
    switch (opt1) {
    | Some(_) => opt1
    | None => opt2
    };

  let (or) = (opt, default) =>
    switch (opt) {
    | Some(x) => x
    | None => default
    };

  let or_fail = (err, opt) =>
    switch (opt) {
    | Some(x) => x
    | None => failwith(err)
    };
};

let (or) = Option.(or);

