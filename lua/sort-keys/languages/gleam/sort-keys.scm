;; Gleam labelled arguments: record/function-call `arguments`, record
;; definition `data_constructor_arguments`, and record update
;; `record_update_arguments`. A positional argument (no label) keeps its slot,
;; which a static query can't classify, so the custom extractor does the
;; labelling.

((arguments) @sortkeys.args)
((data_constructor_arguments) @sortkeys.def_args)
((record_update_arguments) @sortkeys.update_args)
((argument) @sortkeys.arg)
((data_constructor_argument) @sortkeys.def_arg)
((record_update_argument) @sortkeys.update_arg)

((comment) @sortkeys.comment)
