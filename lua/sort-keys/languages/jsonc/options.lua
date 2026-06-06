-- JSONC has no grammar of its own; it reuses the json tree-sitter parser,
-- which accepts comments. The filetype is "jsonc", so parser_lang must be
-- pinned rather than defaulted to the filetype name.
return { parser_lang = "json" }
