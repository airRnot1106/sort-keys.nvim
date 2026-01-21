---Command handlers for sort-keys
local config = require("sort-keys.config")
local adapters = require("sort-keys.adapters")
local sorter = require("sort-keys.core.sorter")

local M = {}

---Sort keys command handler
---@param opts SortKeysOptions
---@param range? {start_row: integer, end_row: integer}
function M.sort_keys(opts, range)
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  -- Get adapter for current filetype
  local adapter = adapters.get(filetype)
  if not adapter then
    vim.notify(
      string.format("No sort-keys adapter for filetype: %s. Supported: %s", filetype, table.concat(adapters.get_supported_filetypes(), ", ")),
      vim.log.levels.WARN
    )
    return
  end

  -- Merge with default options
  local merged_opts = config.get_options(opts)

  -- Execute sort
  sorter.sort(bufnr, adapter, merged_opts, range)
end

return M
