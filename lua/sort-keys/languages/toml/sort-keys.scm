;; TOML inline tables (comma-separated), [table] / [[table]] sections
;; (newline-separated; the header is kept in the container prefix), and arrays.

;; ─── containers ───
((inline_table) @sortkeys.container
 (#set! sortkeys.kind "object"))

((table) @sortkeys.container
 (#set! sortkeys.kind "object"))

((table_array_element) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── pairs (key value have no field labels: key is first, value second) ───
((pair
   (_) @sortkeys.key
   (_) @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── array elements ───
((array
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
