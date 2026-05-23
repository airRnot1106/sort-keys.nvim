-- Specs use this to `pending(...)` early when the language's parser is not
-- installed, so the test suite stays green on minimal environments instead
-- of failing on `vim.treesitter.get_parser` errors.

local M = {}

function M.has_parser(lang)
  -- `vim.treesitter.language.add` can succeed even when no parser binary is
  -- actually on &runtimepath, so the pcall guard alone is unreliable. We
  -- additionally require an actual `parser/<lang>.{so,dylib,dll}` file.
  if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0 then
    return false
  end
  return pcall(vim.treesitter.language.add, lang)
end

return M
