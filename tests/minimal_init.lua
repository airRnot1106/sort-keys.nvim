-- Minimal init.lua for testing sort-keys.nvim

-- Add current directory to runtimepath
vim.opt.rtp:prepend "."

-- Add mini.nvim to runtimepath (for mini.test)
local mini_path = vim.fn.stdpath "data" .. "/site/pack/deps/start/mini.nvim"
vim.opt.rtp:prepend(mini_path)

-- Disable swap files
vim.opt.swapfile = false

-- Set up mini.test
require("mini.test").setup()

-- Initialize sort-keys
require("sort-keys").setup()
