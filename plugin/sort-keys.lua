if vim.g.loaded_sort_keys then
  return
end
vim.g.loaded_sort_keys = true

local command = require("sort-keys.command")

-- :SortKeys sorts the container at the cursor (or the Visual selection);
-- :DeepSortKeys additionally recurses into nested containers. Both accept a
-- `:sort`-compatible bang + flags.
local function sort_keys(opts)
  command.run(opts, false)
end

local function deep_sort_keys(opts)
  command.run(opts, true)
end

vim.api.nvim_create_user_command("SortKeys", sort_keys, {
  range = true,
  bang = true,
  nargs = "?",
  desc = "Sort keys in the container at the cursor/selection",
})

vim.api.nvim_create_user_command("DeepSortKeys", deep_sort_keys, {
  range = true,
  bang = true,
  nargs = "?",
  desc = "Sort keys recursively into nested containers",
})
