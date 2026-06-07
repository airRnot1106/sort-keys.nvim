;; TOML inline tables (comma-separated), [table] / [[table]] sections
;; (newline-separated; the header is kept in the container prefix), and arrays.

;; ─── containers ───
;; The document is an object whose entries are the top-level `pair`s (the keys
;; above any [table]). The `[table]` / `[[table]]` sections are not pairs, so
;; they are not entries; since they always follow the top-level keys they fall
;; into the container suffix and ride along untouched. Scoped to a document that
;; HAS a direct pair: otherwise a single-section file's document and its table
;; share the same range and the document (with no entries) would win the tie.
((document (pair)) @sortkeys.container
 (#set! sortkeys.kind "object"))

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
