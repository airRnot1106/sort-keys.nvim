;; Captures and `#set! sortkeys.*` metadata follow the sortkeys.* convention
;; that the declarative builder reads; renaming them would silently break
;; every filetype's query.

;; ─── containers ───
((object) @sortkeys.container
 (#set! sortkeys.kind "object"))

((array) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── entries (object) ───
;; Capture the whole string node (not its string_content) so an empty-string
;; key "" — which has no string_content child — is still captured; the
;; normalizer strips the quotes.
((pair
   key:   (string) @sortkeys.key
   value: (_)      @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── entries (array) ───
((array
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))
