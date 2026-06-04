; Map bodies (`%{...}`, `%Struct{...}`) hold either atom-shorthand pairs or
; arrow binary operators; both are name-keyed, so the map sorts as an object.
((map) @sortkeys.container
 (#set! sortkeys.kind "object"))

; A list is only sortable when it is a keyword list — i.e. it has a `keywords`
; child. A plain `[1, 2, 3]` is positional and must not match.
((list (keywords)) @sortkeys.container
 (#set! sortkeys.kind "object"))

; Atom-shorthand entry: `key: value`. The `keyword` / `quoted_keyword` node
; carries the trailing colon; key_normalize.elixir strips it.
((pair
   key: (_) @sortkeys.key
   value: (_) @sortkeys.value) @sortkeys.entry
 (#set! sortkeys.entry_kind "pair"))

; Arrow entry: `key => value`. Only binary operators sitting directly inside a
; `map_content` are `=>` pairs; restricting to that parent keeps other binary
; operators out.
((map_content
   (binary_operator
     left: (_) @sortkeys.key
     right: (_) @sortkeys.value) @sortkeys.entry)
 (#set! sortkeys.entry_kind "pair"))

(comment) @sortkeys.comment
