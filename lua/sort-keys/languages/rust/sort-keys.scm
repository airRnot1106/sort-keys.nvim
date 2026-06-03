;; Captures follow the sortkeys.* convention the declarative builder reads.
;;
;; Containers:
;;   `field_declaration_list` — struct-definition body `{ a: u32, b: u32 }`
;;   `field_initializer_list` — struct-literal body  `{ a: 1, b: 2 }`
;;   `use_list`               — grouped use entries  `{ a, b, c }`
;;
;; Deliberately NOT captured as containers:
;;   `enum_variant_list` — derived `Ord` / implicit discriminants make
;;                         variant order semantically significant.
;;   `match_block`       — pattern-overlap order is semantically significant.
;;   `array_expression`  — `[a, b, c]` is positional; reordering changes
;;                         indexing semantics.
;;   `tuple_expression`  — `(a, b)` is positional.
;;   `parameters` / `arguments` — positional.

((field_declaration_list) @sortkeys.container (#set! sortkeys.kind "object"))
((field_initializer_list) @sortkeys.container (#set! sortkeys.kind "object"))
((use_list)               @sortkeys.container (#set! sortkeys.kind "array"))

;; ─── entries (struct definition) ───
;; A `field_declaration` is `[vis] name: ty`; we grab its `field_identifier`
;; as the sort_key. The `name:` field accessor is grammar-stable in
;; tree-sitter-rust, so it isolates the key even when a visibility_modifier
;; precedes it.
((field_declaration
   name: (field_identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── entries (struct literal) ───
;; `field_initializer` is the regular `name: expr`; the `field:` accessor
;; picks the key for sorting and lets the value side be reached for deep
;; recursion in the builder.
((field_initializer
   field: (field_identifier) @sortkeys.key
   value: (_) @sortkeys.value) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; `Foo { a, b }` shorthand — the entry IS the identifier (no `:`); the
;; identifier serves as both surface key and value.
((shorthand_field_initializer
   (identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; `..base` struct-update — captured so the builder can classify it as
;; movable=false and keep its semantic role of "fill remaining fields from".
((base_field_initializer) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── entries (use_list) ───
;; A `use_list` body is a sequence of `identifier` / `self` / `scoped_identifier`
;; / `scoped_use_list` / `use_as_clause` children. We treat them as opaque
;; elements; the builder normalizes their surface text into sort_keys.
((use_list (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; ─── comments + attributes ───
;; Doc comments (`///`, `//!`) surface as `line_comment` nodes; regular line
;; and block comments arrive the same way. An `attribute_item` (`#[derive]`,
;; `#[serde(...)]`) is not a comment syntactically but plays the same
;; structural role inside a container — it precedes the next item and must
;; travel with it. Routing it through `@sortkeys.comment` reuses
;; `core/comment_attach`'s "leading attaches to the next entry" rule without
;; growing a Rust-specific concept in the policy layer.
((line_comment) @sortkeys.comment)
((block_comment) @sortkeys.comment)
((attribute_item) @sortkeys.comment)
