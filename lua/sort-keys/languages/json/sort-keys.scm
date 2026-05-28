;; Captures and `#set! sortkeys.*` metadata follow the sortkeys.* convention
;; that the declarative builder reads; renaming them would silently break
;; every filetype's query.

;; ─── containers ───
((object) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── entries (object) ───
((pair
   key:   (string (string_content) @sortkeys.key)
   value: (_)                       @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── entries (array) ───
((array
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))
