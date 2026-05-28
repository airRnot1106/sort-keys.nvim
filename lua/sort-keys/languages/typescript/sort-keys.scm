;; tree-sitter-typescript inherits these node names from tree-sitter-javascript,
;; so the captures and metadata match queries/javascript/sort-keys.scm 1:1.

;; ─── containers ───
((object) @sortkeys.container (#set! sortkeys.kind "object"))
((array)  @sortkeys.container (#set! sortkeys.kind "array"))

;; ─── object entries ───
((pair)                          @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((shorthand_property_identifier) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((spread_element)                @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((method_definition)             @sortkeys.entry (#set! sortkeys.entry_kind "pair"))

;; ─── array elements ───
((array (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
