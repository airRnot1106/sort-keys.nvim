;; Lua tables are one AST node (table_constructor) for both object-like and
;; array-like tables, so the container kind cannot be tagged statically — the
;; custom extractor (languages/lua/extractor.lua) votes it from the fields.
;; These captures therefore use the extractor's own names, not the generic
;; sortkeys.entry/kind metadata convention.

((table_constructor) @sortkeys.container)

((field) @sortkeys.field)

((comment) @sortkeys.comment)
