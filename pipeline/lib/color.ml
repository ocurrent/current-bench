(** Using the OKLCH colour model. See https://bottosson.github.io/posts/oklab/
    for details about the model,
    https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/oklch for
    details about the implem, and https://oklch.com/ for a color picker.

    - l is lightness: a percentage
    - c is chroma ("amount of color"): a percentage
    - h is hue: an angle in the hue circle, between 0 and 360
    - a is transparency: 0 means invisible, 1 means opaque. *)

type t = { l : float; c : float; h : float; a : float }

let v ?(l = 50.0) ?(c = 100.0) ?(h = 0.0) ?(a = 1.0) () = { l; c; h; a }
let black = v ~l:0.0 ~c:0.0 ()
let white = v ~l:100.0 ~c:0.0 ()
let transparent = v ~a:0.0 ()
let random () = v ~h:(Random.float 360.0) ()

let to_css t =
  let pp_a () = function 1.0 -> "" | n -> Printf.sprintf " %f" n in
  Printf.sprintf "oklch(%f%% %f%% %fdeg%a)" t.l t.c t.h pp_a t.a
