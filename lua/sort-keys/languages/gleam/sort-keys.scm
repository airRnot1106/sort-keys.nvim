;; Gleam labelled arguments: record/function-call `arguments` and record
;; definition `data_constructor_arguments`. A positional argument (no label)
;; must keep its slot, which a static query can't classify, so the custom
;; extractor (languages/gleam/extractor) does the labelling.

((arguments) @sortkeys.args)
((data_constructor_arguments) @sortkeys.def_args)
((argument) @sortkeys.arg)
((data_constructor_argument) @sortkeys.def_arg)

((comment) @sortkeys.comment)
