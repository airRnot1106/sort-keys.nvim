-- Rust keys reach this layer as bare identifiers (struct field names,
-- shorthand initializers, use-list members). The only escape to undo is the
-- raw-identifier prefix `r#`, which Rust uses to allow keywords as identifier
-- names (e.g. `r#type`, `r#match`, `foo::r#type`). The prefix is stripped on
-- every component so the same logical path round-trips to a single sort_key
-- regardless of whether the source spells it `foo::r#bar` or `foo::bar`. The
-- character `#` is otherwise inadmissible inside a Rust identifier, so a
-- global gsub cannot collide with a legitimate sub-string.
---@param text string  -- raw node text from a Rust field / use-list identifier
---@return string
return function(text)
  return (text:gsub("r#", ""))
end
