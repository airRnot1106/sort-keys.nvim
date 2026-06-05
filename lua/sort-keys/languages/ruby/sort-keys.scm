;; Ruby hashes/arrays on the generic extractor. A hash_splat_argument (**base)
;; is order-sensitive (a later key overrides) so it is fenced.

;; ─── containers ───
((hash) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; A method call's keyword arguments `foo(b: 1, a: 2)` (no braces) live in an
;; argument_list, not a hash. Sortable only when it holds at least one `pair`;
;; positional args carry no `key` field so they are not entries, and since Ruby
;; requires kwargs to come last they fall into the container prefix and keep
;; their slot.
((argument_list (pair)) @sortkeys.container
 (#set! sortkeys.kind "object"))

;; A `case`/`in` hash pattern `in { name:, age: }`; its keyword_pattern members
;; carry a key, so reordering them is safe.
((hash_pattern (keyword_pattern)) @sortkeys.container
 (#set! sortkeys.kind "object"))

;; ─── hash pairs (key is a symbol / string / simple_symbol) ───
;; The value is optional so a Ruby 3.1 shorthand pair `{ x:, y: }` (key, no
;; value) is still captured and sorts by its key.
((pair
   key:   (_)  @sortkeys.key
   value: (_)? @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── hash-pattern members `name:` / `name: pattern` ───
((keyword_pattern
   key: (_) @sortkeys.key
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
