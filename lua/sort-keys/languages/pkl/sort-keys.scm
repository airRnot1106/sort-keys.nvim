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

;; ─── comments ───
((lineComment) @sortkeys.comment)
((blockComment) @sortkeys.comment)
