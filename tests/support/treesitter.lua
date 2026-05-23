-- Specs use this to `pending(...)` early when the language's parser is not
-- installed, so the test suite stays green on minimal environments instead
-- of failing on `vim.treesitter.get_parser` errors.

local M = {}

function M.has_parser(lang)
  local ok = pcall(vim.treesitter.language.add, lang)
  return ok
end

return M
