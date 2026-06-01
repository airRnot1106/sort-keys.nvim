;; Captures follow the sortkeys.* convention the declarative builder reads.
;;
;; Containers:
;;   `dictionary` — `{k: v, ...}` object literal
;;   `list`       — `[1, 2, 3]` list literal
;;   `set`        — `{1, 2, 3}` set literal (the empty `{}` is a dict, not a set)
;; `tuple` is intentionally NOT a container: `(x, y)` is positional and
;; reordering changes the semantics (e.g. coordinate pairs).

((dictionary) @sortkeys.container (#set! sortkeys.kind "object"))
((list)       @sortkeys.container (#set! sortkeys.kind "array"))
((set)        @sortkeys.container (#set! sortkeys.kind "array"))

;; Dict entries: `pair` is the regular `key: value`; `dictionary_splat`
;; (`**other`) is captured here but classified as movable=false by the
;; builder because spread order is semantically significant.
((pair)             @sortkeys.entry (#set! sortkeys.entry_kind "pair"))
((dictionary_splat) @sortkeys.entry (#set! sortkeys.entry_kind "pair"))

;; List / set elements as wildcard children. The builder later drops any
;; entry whose node was also captured as a comment.
((list (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))
((set  (_) @sortkeys.entry) (#set! sortkeys.entry_kind "element"))

((comment) @sortkeys.comment)
