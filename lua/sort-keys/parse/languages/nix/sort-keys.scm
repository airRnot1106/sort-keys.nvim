;; Nix attribute sets on the generic extractor. The bindings live under a
;; binding_set node (the attrset/rec/let braces are outside it), so binding_set
;; is the container; ";" is the separator. A nested attrset is found one level
;; down (attrset_expression wraps its own binding_set) for deep recursion.

;; ─── containers ───
((binding_set) @sortkeys.container
 (#set! sortkeys.kind "object"))

;; A list `[ c b a ]` is array-like.
((list_expression) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; Function formal args `{ b, a }:` are keyed (each formal has a name); the
;; trailing `...` (ellipses) is not a formal so it stays put in the suffix.
((formals) @sortkeys.container
 (#set! sortkeys.kind "object"))

;; The identifier list of `inherit a b c;` / `inherit (scope) a b c;` is an
;; array-like container: the cursor on one of the names sorts the list. The
;; enclosing inherit / inherit_from is a pinned ENTRY of the binding_set below,
;; so the two roles coexist — outer pinned binding, inner identifier container.
((inherited_attrs) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── bindings ───
((binding
   attrpath:   (_) @sortkeys.key
   expression: (_) @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; `inherit a b;` has no key and its placement is incidental: pin it so it stays
;; put (and is never dropped) while keyed bindings sort around it.
((inherit) @sortkeys.entry @sortkeys.pin
 (#set! sortkeys.entry_kind "element"))

;; `inherit (scope) a b;` is a distinct node (inherit_from); pin it too so it is
;; never dropped and keyed bindings sort around it.
((inherit_from) @sortkeys.entry @sortkeys.pin
 (#set! sortkeys.entry_kind "element"))

;; ─── list elements (named children; `[` `]` are anonymous) ───
((list_expression
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; ─── function formal arg `a` or `a ? default` ───
((formal
   name: (_) @sortkeys.key
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── identifiers inside an `inherit` / `inherit (scope)` list ───
(inherited_attrs
  (identifier) @sortkeys.entry
  (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
