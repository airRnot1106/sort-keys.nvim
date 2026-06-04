;; Elixir maps/keyword lists come in two shapes the generic query can't unify,
;; so the custom extractor handles them: atom-key `%{a: 1}` / keyword lists put
;; pairs under a `keywords` node; arrow `%{"a" => 1}` puts binary_operators
;; under `map_content`.

((keywords) @sortkeys.keywords)
((pair) @sortkeys.pair)
((map_content (binary_operator) @sortkeys.arrow))

((comment) @sortkeys.comment)
