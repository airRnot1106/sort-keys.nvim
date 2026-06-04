-- Gleam argument labels reach this layer as bare snake_case identifiers
-- (`name`, `cuteness`) with no quoting or escapes, so the logical key is the
-- surface text verbatim.
---@param text string  -- raw node text from a Gleam argument / field label
---@return string
return function(text)
  return text
end
