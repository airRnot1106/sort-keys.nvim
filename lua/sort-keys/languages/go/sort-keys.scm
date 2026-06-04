;; Go containers are collected by the custom extractor (languages/go/extractor):
;; a literal_value is sortable only when it has keyed elements (struct/map),
;; which a static query can't tag, so these captures feed the extractor's own
;; logic rather than the generic kind/entry_kind metadata convention.

((literal_value) @sortkeys.literal_value)
((field_declaration_list) @sortkeys.field_list)
((import_spec_list) @sortkeys.import_list)

((keyed_element) @sortkeys.keyed)
((field_declaration) @sortkeys.field)
((import_spec) @sortkeys.import)

((comment) @sortkeys.comment)
