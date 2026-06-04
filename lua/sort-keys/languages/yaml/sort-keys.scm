;; YAML block and flow mappings on the generic extractor. Block style is
;; newline-separated (the observed separator is ""), flow style is ",". The
;; value is optional so a null-value key `b:` is still captured.

;; ─── containers ───
((block_mapping) @sortkeys.container
 (#set! sortkeys.kind "object"))

((flow_mapping) @sortkeys.container
 (#set! sortkeys.kind "object"))

;; ─── mapping pairs ───
((block_mapping_pair
   key:   (_)  @sortkeys.key
   value: (_)? @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((flow_pair
   key:   (_)  @sortkeys.key
   value: (_)? @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── comments ───
((comment) @sortkeys.comment)
