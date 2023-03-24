(* Warning: This library is used in the pipeline, the checker, AND the frontend.
 * It must remain compatible with Rescript ~= OCaml 4.06 with a few missing stdlib modules
 * and must have no external dependency.
 *)

module Json = Json
module S = Schema
