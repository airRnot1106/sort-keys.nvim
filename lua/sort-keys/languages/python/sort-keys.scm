;; Python dicts/lists on the generic extractor; a dictionary_splat (**base) is
;; order-sensitive (a later key overrides an earlier one) so it is fenced.

;; ─── containers ───
((dictionary) @sortkeys.container
 (#set! sortkeys.kind "object"))

((list) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; A set literal `{1, 2, 3}` is array-like; the empty `{}` parses as a
;; `dictionary`, not a `set`, so it is not captured here.
((set) @sortkeys.container
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

;; ─── set elements ───
((set
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; A `*rest` unpacks at its position, so its order relative to siblings is
;; meaningful: fence it. (It is also captured as an element above; the fence
;; flag is keyed by node id and applies regardless.)
((list_splat) @sortkeys.fence)

;; ─── comments ───
((comment) @sortkeys.comment)
