;; JSONC rides on the json parser (which accepts comments). Same captures as
;; json, plus the comment capture so core.comment_fold can carry a comment
;; with the pair it documents instead of letting it drift after :SortKeys.

;; ─── containers ───
((object) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── entries (object) ───
;; Capture the whole string node so an empty-string key "" (no string_content
;; child) is still captured; the normalizer strips the quotes.
((pair
   key:   (string) @sortkeys.key
   value: (_)      @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── entries (array) ───
((array
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
