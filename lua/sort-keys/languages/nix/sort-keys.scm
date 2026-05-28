; sort-keys.nvim — Nix query
;
; Captures:
;   @sortkeys.container — every sortable container shape
;   @sortkeys.entry     — every direct entry slot inside a container
;   @sortkeys.comment   — every `#` / `/* */` comment

((attrset_expression) @sortkeys.container
  (#set! sortkeys.kind "object"))

((rec_attrset_expression) @sortkeys.container
  (#set! sortkeys.kind "object"))

((let_expression) @sortkeys.container
  (#set! sortkeys.kind "object"))

((list_expression) @sortkeys.container
  (#set! sortkeys.kind "array"))

((formals) @sortkeys.container
  (#set! sortkeys.kind "object"))

; `inherit ... ;` and `inherit (e) ... ;` are also containers (kind=array)
; so the user can place the cursor on the `inherit` keyword or the source
; `(e)` and still sort the identifier list. The same nodes are also
; captured as @sortkeys.entry below — they live in both roles: outer
; pinned binding inside an attrset, AND inner container for the
; identifiers.
((inherit) @sortkeys.container
  (#set! sortkeys.kind "array"))

((inherit_from) @sortkeys.container
  (#set! sortkeys.kind "array"))

; Regular `attrpath = value;` bindings inside attrset / rec_attrset / let.
((binding) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

; `inherit a b c;` — entry pinned, child container handles identifier sort.
((inherit) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

; `inherit (foo) a b c;` — same shape with a source expression.
((inherit_from) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

; Named list children are values (variable / integer / string / attrset /
; list / ...). `[`, `]` are anonymous and don't match `(_)`.
(list_expression
  (_) @sortkeys.entry
  (#set! sortkeys.entry_kind "element"))

; Function formal arg `a` or `a ? default`.
((formal) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

; `...` in `{ a, ... }:` — always pinned at the tail.
((ellipses) @sortkeys.entry
  (#set! sortkeys.entry_kind "element"))

; Each identifier inside an `inherit` / `inherit_from`.
(inherited_attrs
  (identifier) @sortkeys.entry
  (#set! sortkeys.entry_kind "element"))

((comment) @sortkeys.comment)
