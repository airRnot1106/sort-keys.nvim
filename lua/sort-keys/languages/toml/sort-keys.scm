; sort-keys.nvim — TOML query
;
; Captures:
;   @sortkeys.container — every node we may sort inside
;   @sortkeys.entry     — every direct child slot of a container that can move
;   @sortkeys.comment   — every `#` comment (comment_attach decides ownership)
;
; The root-level pair group (document-direct pairs) is synthesized by the
; builder, so there is no `(document) @sortkeys.container` capture here.

((inline_table) @sortkeys.container
  (#set! sortkeys.kind "object"))

((table) @sortkeys.container
  (#set! sortkeys.kind "object"))

((table_array_element) @sortkeys.container
  (#set! sortkeys.kind "object"))

((array) @sortkeys.container
  (#set! sortkeys.kind "array"))

((pair) @sortkeys.entry
  (#set! sortkeys.entry_kind "pair"))

; Named children of `array` are values (string / integer / float / boolean /
; inline_table / array / date / time / ...). The anonymous `[`, `]`, `,`
; tokens are not named and therefore don't match `(_)`.
(array
  (_) @sortkeys.entry
  (#set! sortkeys.entry_kind "element"))

((comment) @sortkeys.comment)
