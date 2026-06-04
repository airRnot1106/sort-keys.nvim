;; JavaScript stays declarative on the generic extractor: every object member
;; kind is captured so none is dropped, and order-sensitive members are pinned
;; or fenced via the @sortkeys.pin / @sortkeys.fence captures.

;; ─── containers ───
((object) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── object members ───
;; normal key: string / identifier / number
((pair
   key:   [(property_identifier) (string) (number)] @sortkeys.key
   value: (_)                                       @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; shorthand `{ a, b }`
((shorthand_property_identifier) @sortkeys.entry @sortkeys.key
 (#set! sortkeys.entry_kind "pair"))

;; computed key `{ [k]: v }` — a later key can shadow an earlier one, so the
;; relative order is meaningful: fence it.
((pair
   key:   (computed_property_name)
   value: (_) @sortkeys.value
 ) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))

;; spread `{ ...x }` — order-sensitive (a later spread/key overrides): fence.
((spread_element) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))

;; method / getter / setter — keep in place so paired get/set never reorder.
((method_definition) @sortkeys.entry @sortkeys.pin
 (#set! sortkeys.entry_kind "element"))

;; ─── array elements ───
((array
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
