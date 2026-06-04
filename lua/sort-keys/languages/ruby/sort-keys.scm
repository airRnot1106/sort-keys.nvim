;; Ruby hashes/arrays on the generic extractor. A hash_splat_argument (**base)
;; is order-sensitive (a later key overrides) so it is fenced.

;; ─── containers ───
((hash) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── hash pairs (key is a symbol / string / simple_symbol) ───
((pair
   key:   (_) @sortkeys.key
   value: (_) @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── ** splat -> fence ───
((hash_splat_argument) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))

;; ─── array elements ───
((array
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
