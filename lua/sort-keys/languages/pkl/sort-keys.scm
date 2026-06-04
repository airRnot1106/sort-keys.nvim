;; Pkl object bodies on the generic extractor. Properties (`b = 1`) and entries
;; (`["b"] = 1`) sort by key; a nested object body is found one level down for
;; deep recursion. Block style is newline-separated (observed separator "").

;; ─── containers ───
((objectBody) @sortkeys.container
 (#set! sortkeys.kind "object"))

;; ─── members ───
((objectProperty (identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((objectEntry key: (_) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; An objectBody also holds positional elements, spreads, and generators. They
;; have no key and their order is meaningful, so capture them as FENCED entries:
;; this keeps them in the buffer (never dropped) and stops keyed members from
;; reordering across them.
((objectElement) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))
((objectSpread) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))
((forGenerator) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))
((whenGenerator) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((lineComment) @sortkeys.comment)
((blockComment) @sortkeys.comment)
