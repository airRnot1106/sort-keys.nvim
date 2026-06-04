;; Nix attribute sets on the generic extractor. The bindings live under a
;; binding_set node (the attrset/rec/let braces are outside it), so binding_set
;; is the container; ";" is the separator. A nested attrset is found one level
;; down (attrset_expression wraps its own binding_set) for deep recursion.

;; ─── container ───
((binding_set) @sortkeys.container
 (#set! sortkeys.kind "object"))

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

;; ─── comments ───
((comment) @sortkeys.comment)
