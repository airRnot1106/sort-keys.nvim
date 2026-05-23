;; Mirror of queries/yaml/sort-keys.scm so the `.yml` filetype resolves to
;; an identical query. Keep the two in sync.

((block_mapping)  @sortkeys.container (#set! sortkeys.kind "object"))
((block_sequence) @sortkeys.container (#set! sortkeys.kind "array"))
((flow_mapping)   @sortkeys.container (#set! sortkeys.kind "object"))
((flow_sequence)  @sortkeys.container (#set! sortkeys.kind "array"))

((block_mapping_pair) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((flow_pair)          @sortkeys.entry (#set! sortkeys.entry_kind "pair"))

((block_sequence_item)              @sortkeys.entry (#set! sortkeys.entry_kind "element"))
((flow_sequence (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))

((comment) @sortkeys.comment)
