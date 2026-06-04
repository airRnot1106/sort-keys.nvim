;; Ruby hashes/arrays on the generic extractor. A hash_splat_argument (**base)
;; is order-sensitive (a later key overrides) so it is fenced.

;; ─── containers ───
((hash) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── hash pairs (key is a symbol / string / simple_symbol) ───
;; The value is optional so a Ruby 3.1 shorthand pair `{ x:, y: }` (key, no
;; value) is still captured and sorts by its key.
((pair
   key:   (_)  @sortkeys.key
   value: (_)? @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── ** splat -> fence ───
((hash_splat_argument) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))

;; ─── array elements ───
((array
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; A `*a` array splat splices at its position, so its order is meaningful: fence
;; it (also captured as an element above; the fence flag is keyed by node id).
((array
   (splat_argument) @sortkeys.fence))

;; ─── comments ───
((comment) @sortkeys.comment)
