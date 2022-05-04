open Cobench

let test_fact () =
  let x = ref 10 in
  let i = ref 10 in
  while !x >= 2 do
    i := !i * (!x - 1);
    x := !x -1
  done; !i

let test_fibo () =
  let rec fibonacci n =
    match n with
    |0 -> 0
    |1 -> 1
    |n -> fibonacci (n-1) + fibonacci (n-2) in
  fibonacci 10

let bech_of_sys_fact =  bench ~quota:1.1 "bench" "factorial" test_fact
let bech_of_sys_fibo =  bench ~quota:1.1 "bench" "fibonacci" test_fibo
