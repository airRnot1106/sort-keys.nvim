;; Rust struct literals (field_initializer_list), struct definitions
;; (field_declaration_list), and use lists (use_list). `..base` is fenced;
;; #[attr] items ride as comments so they travel with the field they annotate.

;; ─── containers ───
((field_initializer_list) @sortkeys.container
 (#set! sortkeys.kind "object"))

((field_declaration_list) @sortkeys.container
 (#set! sortkeys.kind "object"))

((use_list) @sortkeys.container
 (#set! sortkeys.kind "array"))

;; ─── struct-literal fields ───
((field_initializer
   field: (field_identifier) @sortkeys.key
   value: (_)                @sortkeys.value
 ) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((shorthand_field_initializer (identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; `..base` is order-sensitive (it fills remaining fields): fence it.
((base_field_initializer) @sortkeys.entry @sortkeys.fence
 (#set! sortkeys.entry_kind "element"))

;; ─── struct-definition fields ───
((field_declaration name: (field_identifier) @sortkeys.key) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

;; ─── use list items ───
((use_list (_) @sortkeys.entry)
 (#set! sortkeys.entry_kind "element"))

;; `self` in `use a::{self, ...}` conventionally stays first; pin it so it does
;; not alphabetize away from its slot.
((use_list (self) @sortkeys.pin))

;; ─── comments (attributes ride as comments) ───
((attribute_item) @sortkeys.comment)
((line_comment) @sortkeys.comment)
((block_comment) @sortkeys.comment)
