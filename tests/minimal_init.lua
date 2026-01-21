-- Minimal init for testing sort-keys.nvim
vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- Ensure treesitter is available
local ok, _ = pcall(require, "nvim-treesitter")
if not ok then
  -- Try to use built-in treesitter
  print("nvim-treesitter not found, using built-in treesitter")
end

-- Setup the plugin
require("sort-keys").setup({})
