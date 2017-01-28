(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)


module Cmap = Map.Make (Char)                           (* character maps. *)

type 'a value =                         (* type for holding a bound value. *)
| Pre of 'a                    (* value is bound by the prefix of a key. *)
| Key of 'a                          (* value is bound by an entire key. *)
| Amb                     (* no value bound because of ambiguous prefix. *)
| Nil                            (* not bound (only for the empty trie). *)

type 'a t = { v : 'a value; succs : 'a t Cmap.t }
let empty = { v = Nil; succs = Cmap.empty }
let is_empty t = t = empty

(* N.B. If we replace a non-ambiguous key, it becomes ambiguous but it's
   not important for our use. Also the following is not tail recursive but
   the stack is bounded by key length. *)
let add t k d =
  let rec aux t k len i d pre_d =
    if i = len then { v = Key d; succs = t.succs } else
    let v = match t.v with
    | Amb | Pre _ -> Amb | Key _ as v -> v | Nil -> pre_d
    in
    let succs =
      let t' = try Cmap.find k.[i] t.succs with Not_found -> empty in
      Cmap.add k.[i] (aux t' k len (i + 1) d pre_d) t.succs
    in
    { v; succs }
  in
  aux t k (String.length k) 0 d (Pre d (* allocate less *))

let find_node t k =
  let rec aux t k len i =
    if i = len then t else
    aux (Cmap.find k.[i] t.succs) k len (i + 1)
  in
  aux t k (String.length k) 0

let find t k =
  try match (find_node t k).v with
  | Key v | Pre v -> `Ok v | Amb -> `Ambiguous | Nil -> `Not_found
  with Not_found -> `Not_found

let ambiguities t p =                        (* ambiguities of [p] in [t]. *)
  try
    let t = find_node t p in
    match t.v with
    | Key _ | Pre _ | Nil -> []
    | Amb ->
        let add_char s c = s ^ (String.make 1 c) in
        let rem_char s = String.sub s 0 ((String.length s) - 1) in
        let to_list m = Cmap.fold (fun k t acc -> (k,t) :: acc) m [] in
        let rec aux acc p = function
        | ((c, t) :: succs) :: rest ->
            let p' = add_char p c in
            let acc' = match t.v with
            | Pre _ | Amb -> acc
            | Key _ -> (p' :: acc)
            | Nil -> assert false
            in
            aux acc' p' ((to_list t.succs) :: succs :: rest)
        | [] :: [] -> acc
        | [] :: rest -> aux acc (rem_char p) rest
        | [] -> assert false
        in
        aux [] p (to_list t.succs :: [])
  with Not_found -> []

let of_list l = List.fold_left (fun t (s, v) -> add t s v) empty l

(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
