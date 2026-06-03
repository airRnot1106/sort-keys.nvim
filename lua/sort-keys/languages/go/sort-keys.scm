;; Captures follow the sortkeys.* convention the shared collect_matches reads.
;;
;; Containers:
;;   `field_declaration_list` — struct definition body (object)
;;   `literal_value`          — struct OR map composite-literal body (object);
;;                              slice / array composite literals also wrap
;;                              their elements in a `literal_value`, so the
;;                              builder filters those out via the parent's
;;                              type child (`slice_type` / `array_type`).
;;   `import_spec_list`       — parenthesized `import ( ... )` group (array)
;;
;; Deliberately NOT captured as containers:
;;   `expression_switch_statement` / `expression_case` — case order is
;;                                                       semantically significant.
;;   `type_switch_statement`                          — same.
;;   `const_declaration` / `var_declaration`          — `iota` makes spec
;;                                                       index meaningful.
;;   `parameter_list`                                 — positional.
;;
;; Slice / array literals share the `literal_value` node with struct / map
;; literals, but their entries are positional `literal_element` children
;; instead of `keyed_element`. The builder skips containers whose entry
;; harvest yields no `keyed_element` entries, so they fall through naturally.

((field_declaration_list) @sortkeys.container (#set! sortkeys.kind "object"))
((literal_value)          @sortkeys.container (#set! sortkeys.kind "object"))
((import_spec_list)       @sortkeys.container (#set! sortkeys.kind "array"))

;; ─── entries (struct definition) ───
;; `field_declaration` has a `name:` field accessor returning the
;; `field_identifier`; we use the positional form here to stay compatible
;; with grammars that don't expose the accessor.
((field_declaration
   (field_identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── entries (composite literal body) ───
;; Inside `literal_value`, only `keyed_element` represents a reorderable
;; entry. Positional `literal_element` siblings are skipped here so the
;; builder doesn't pick a slice / array container as if it were sortable.
((keyed_element) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── entries (import block) ───
;; Each import line is one `import_spec`. The optional `package_identifier`
;; alias is read from the entry node directly in the builder; the sort_key
;; comes from the `interpreted_string_literal` import path.
((import_spec) @sortkeys.entry
 (#set! sortkeys.entry_kind "element"))

;; ─── comments ───
((comment) @sortkeys.comment)
