;; Unlike json/javascript whose container kind (object vs array) is fixed by
;; the AST node type, Lua's `table_constructor` represents both. The builder
;; decides kind dynamically from the field shapes after collecting them, so
;; this query intentionally does NOT attach a `sortkeys.kind` metadata —
;; lua_builder.collect_matches drops the kind guard that json_builder uses.

;; ─── containers ───
((table_constructor) @sortkeys.container)

;; ─── fields (every direct child of a table_constructor) ───
;; Each field is one of: bare-key (`name = v`), bracket-key (`[expr] = v`,
;; sortable when expr is a string literal), or positional (no key). The
;; builder's classify_entry decides movable + sort_key per shape.
((field) @sortkeys.entry)

;; ─── comments ───
;; Both `--` line comments and `--[[ ]]` block comments unify as `comment`.
((comment) @sortkeys.comment)
