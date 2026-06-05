;; KDL has two "key" levels, mirroring JSON: the named `node`s inside a document
;; or a `{ ... }` children block are the outer keys, and a node's `node_field`s
;; (key=value properties) are the inner keys. Which level sorts is decided by the
;; cursor in the custom extractor — a property field can't be told from a
;; positional argument / slashdash by a static query, so these captures feed the
;; extractor's own logic.

((document) @sortkeys.doc)
((node_children) @sortkeys.children)
((node) @sortkeys.node)
((node_field) @sortkeys.field)

((single_line_comment) @sortkeys.comment)
((multi_line_comment) @sortkeys.comment)
