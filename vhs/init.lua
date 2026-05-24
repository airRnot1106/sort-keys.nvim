-- Minimal init.lua for VHS recordings. Loads sort-keys.nvim from the
-- current working directory (the repo root) so the demo always reflects
-- the code that's checked out, not an installed copy.

vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.swapfile = false
vim.opt.hlsearch = false
vim.opt.termguicolors = true
vim.opt.number = true
vim.cmd("runtime plugin/sort-keys.lua")
require("sort-keys").setup({})
require("lualine").setup({
  options = {
    icons_enabled = false,
    section_separators = "",
    component_separators = "",
  },
})
