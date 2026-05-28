;; Pkl has two container shapes and the object-vs-array distinction is not
;; carried by a single node type: a `module` is always object-like (its
;; `classProperty` children are keyed), while an `objectBody` can be a
;; property block, a mapping, or a listing. The builder decides kind per
;; container by voting on the entry shapes it collects, so this query does
;; NOT attach `sortkeys.kind` metadata (mirrors lua's table_constructor).

;; ─── containers ───
((module) @sortkeys.container)
((objectBody) @sortkeys.container)

;; ─── entries ───
;; Module-level property: `name = value` / `bird { ... }`.
((classProperty) @sortkeys.entry)
;; Property inside an object body: `name = value`.
((objectProperty) @sortkeys.entry)
;; Mapping entry: `["key"] = valueExpr`.
((objectEntry) @sortkeys.entry)
;; Listing element: a bare value with no key.
((objectElement) @sortkeys.entry)

;; ─── comments ───
;; Pkl's `//` line, `/* */` block, and `///` doc comments are distinct node
;; types; all three travel with the entry comment_attach binds them to.
((lineComment) @sortkeys.comment)
((blockComment) @sortkeys.comment)
((docComment) @sortkeys.comment)
