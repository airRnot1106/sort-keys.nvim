; A record / function-call argument list is sortable only when it holds at
; least one labelled argument; a purely positional call must not match.
((arguments (argument label: (label))) @sortkeys.container
 (#set! sortkeys.kind "object"))

; A custom-type constructor's field list, same labelled-field rule.
((data_constructor_arguments (data_constructor_argument label: (label))) @sortkeys.container
 (#set! sortkeys.kind "object"))

; A record-update field list (`Pet(..base, age: 4, name: "x")`); the spread is
; a sibling of this node, so sorting touches only the labelled fields.
((record_update_arguments (record_update_argument label: (label))) @sortkeys.container
 (#set! sortkeys.kind "object"))

; A record pattern's field list in a `case` clause (`Foo(a: x, b: y) -> ...`).
((record_pattern_arguments (record_pattern_argument label: (label))) @sortkeys.container
 (#set! sortkeys.kind "object"))

; Every argument / field / pattern is captured as an entry, including
; positional ones (no `label` field): the builder pins those so they keep
; their slot and the applier still sees the full list. The label and the
; inner subtree (value for arguments, pattern for patterns) are read from the
; node's fields in the builder.
((argument) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((data_constructor_argument) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((record_update_argument) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

((record_pattern_argument) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

(comment) @sortkeys.comment
