-- Rust field names / use items are bare identifiers; pass them through. A raw
-- identifier `r#type` keeps its `r#` (it denotes the same name, sorted as-is).
---@param text string
---@return string
return function(text)
  return text
end
