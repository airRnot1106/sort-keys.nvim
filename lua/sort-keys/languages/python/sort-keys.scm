;; Python dicts/lists on the generic extractor; a dictionary_splat (**base) is
;; order-sensitive (a later key overrides an earlier one) so it is fenced.

;; ─── containers ───
((dictionary) @sortkeys.container
 (#set! sortkeys.kind "object"))

((list) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── dict pairs (key is any expression: string / number / name) ───
((pair
   key:   (_) @sortkeys.key
   value: (_) @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── dict splat **base -> fence ───
((dictionary_splat) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))

;; ─── list elements ───
((list
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
