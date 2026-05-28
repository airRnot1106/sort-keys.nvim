;; Captures and `#set! sortkeys.*` metadata follow the sortkeys.* convention
;; that the declarative builder reads. YAML pairs have no `key:` / `value:`
;; field syntax so the builder reads key / value from named children rather
;; than capturing them at the query level.

;; ─── containers ───
((block_mapping)  @sortkeys.container (#set! sortkeys.kind "object"))
((block_sequence) @sortkeys.container (#set! sortkeys.kind "array"))
((flow_mapping)   @sortkeys.container (#set! sortkeys.kind "object"))
((flow_sequence)  @sortkeys.container (#set! sortkeys.kind "array"))

;; ─── entries — pair ───
((block_mapping_pair) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((flow_pair)          @sortkeys.entry (#set! sortkeys.entry_kind "pair"))

;; ─── entries — element ───
((block_sequence_item)              @sortkeys.entry (#set! sortkeys.entry_kind "element"))
((flow_sequence (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
