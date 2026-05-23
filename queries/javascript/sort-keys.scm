;; Captures and `#set! sortkeys.*` metadata follow the sortkeys.* convention
;; that the declarative builder reads. JavaScript object entries come in
;; several flavours — pair, shorthand, spread, method — and the builder
;; decides sortability / movable per entry kind.

;; ─── containers ───
((object) @sortkeys.container (#set! sortkeys.kind "object"))
((array)  @sortkeys.container (#set! sortkeys.kind "array"))

;; ─── object entries ───
;; Every direct child of `object` that may carry a key gets the entry
;; capture; the builder marks spread / computed-key forms movable=false so
;; their position is preserved (spread order is semantically significant).
((pair)                          @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((shorthand_property_identifier) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((spread_element)                @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((method_definition)             @sortkeys.entry (#set! sortkeys.entry_kind "pair"))

;; ─── array elements ───
((array (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
