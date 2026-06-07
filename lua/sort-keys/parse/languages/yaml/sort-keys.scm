;; YAML block and flow mappings on the generic extractor. Block style is
;; newline-separated (the observed separator is ""), flow style is ",". The
;; value is optional so a null-value key `b:` is still captured.

;; ─── containers ───
((block_mapping) @sortkeys.container
 (#set! sortkeys.kind "object"))

((flow_mapping) @sortkeys.container
 (#set! sortkeys.kind "object"))

((block_sequence) @sortkeys.container
 (#set! sortkeys.kind "array"))

((flow_sequence) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── mapping pairs ───
;; The key is optional so a null-key pair (`: value`, valid YAML) is still
;; captured as an entry — otherwise it leaks into the container prefix and its
;; trailing comment corrupts the layout. A missing key sorts as the empty key.
((block_mapping_pair
   key:   (_)? @sortkeys.key
   value: (_)? @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((flow_pair
   key:   (_)? @sortkeys.key
   value: (_)? @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── sequence items (the `- ` block item and bare flow elements) ───
((block_sequence
   (block_sequence_item) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

((flow_sequence
   (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
