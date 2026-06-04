;; KDL node fields are collected by the custom extractor: a field may be a
;; property (key=value) or a positional argument / slashdash, which the generic
;; query can't distinguish, so these captures feed the extractor's own logic.

((node) @sortkeys.node)
((node_field) @sortkeys.field)

((single_line_comment) @sortkeys.comment)
((multi_line_comment) @sortkeys.comment)
