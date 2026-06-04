; A hash / argument list is sortable only when it holds at least one keyword
; `pair`; a positional-only call or an array literal must not match.
((hash (pair)) @sortkeys.container
 (#set! sortkeys.kind "object"))

((argument_list (pair)) @sortkeys.container
 (#set! sortkeys.kind "object"))

; A `case`/`in` hash pattern (`in { name:, age: }`); its `keyword_pattern`
; members carry a `key` field, so reordering them is safe.
((hash_pattern (keyword_pattern)) @sortkeys.container
 (#set! sortkeys.kind "object"))

; Every direct child is captured as an entry, including positional args and
; `*`/`**` splats (no `key` field): the builder pins those so they keep their
; slot and the applier still sees the full list. The wildcard also catches
; `comment` children, which collect_matches drops from the entry set because
; they are captured as comments below. The key / value are read from the
; pair's fields in the builder.
((hash (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "pair"))

((argument_list (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "pair"))

((hash_pattern (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "pair"))

(comment) @sortkeys.comment
