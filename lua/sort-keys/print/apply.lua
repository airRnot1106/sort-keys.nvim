-- The impure tail of the "print" stage: take the rendered string and write it
-- back over the container's source span. render.lua did the pure work; this is
-- the only buffer mutation in the pipeline.

local M = {}

---@param bufnr integer
---@param outline table  -- needs outline.range = { srow, scol, erow, ecol }
---@param rendered string
function M.apply(bufnr, outline, rendered)
  local r = outline.range
  local lines = vim.split(rendered, "\n", { plain = true })
  vim.api.nvim_buf_set_text(bufnr, r[1], r[2], r[3], r[4], lines)
end

return M
