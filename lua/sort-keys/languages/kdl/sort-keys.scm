;; KDL models a document as a tree of named `node`s. The two sortable
;; containers are the file root (`document`) and every `{ ... }` children
;; block (`node_children`); both hold `node` entries keyed by the node name.
;; KDL has no array shape (positional args are order-significant), so the
;; builder always treats a container as object-like and does NOT read a
;; `sortkeys.kind` metadata (mirrors pkl).

;; ─── containers ───
((document) @sortkeys.container)
((node_children) @sortkeys.container)

;; ─── entries ───
;; Every node is an entry of whichever container it sits directly in (the
;; document root or an enclosing children block); the builder groups them by
;; parent and sorts by the node name.
((node) @sortkeys.entry)

;; ─── comments ───
;; A `//` line comment and a `/* */` block comment that sit between nodes
;; travel with the node comment_attach binds them to. A same-line trailing
;; `//` comment is the node's own terminator and already lives inside the
;; node's range, so it rides along without a separate capture.
[
  (single_line_comment)
  (multi_line_comment)
] @sortkeys.comment
