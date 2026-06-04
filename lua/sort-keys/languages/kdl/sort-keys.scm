;; KDL nodes: sort a node's properties (key=value). Properties are node_fields
;; wrapping a prop; the node's name, positional args, and children block sit
;; outside the property run (in the container prefix/suffix). Separator is " ".

((node) @sortkeys.container
 (#set! sortkeys.kind "object"))

((node_field (prop (identifier) @sortkeys.key)) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((single_line_comment) @sortkeys.comment)
((multi_line_comment) @sortkeys.comment)
