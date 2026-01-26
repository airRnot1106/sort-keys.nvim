-- Minimal init.lua for testing sort-keys.nvim
-- Used by child processes during tests

-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd [[let &rtp.=','.getcwd()]]

-- Add user's tree-sitter parsers and nvim-treesitter to runtimepath
-- This allows child processes to use installed parsers
local data_path = vim.fn.stdpath "data"
vim.opt.runtimepath:append(data_path .. "/site")

-- Try to add nvim-treesitter from common locations
local ts_paths = {
    data_path .. "/site/pack/deps/start/nvim-treesitter",
    data_path .. "/lazy/nvim-treesitter",
    data_path .. "/site/pack/packer/start/nvim-treesitter",
}
for _, path in ipairs(ts_paths) do
    if vim.fn.isdirectory(path) == 1 then
        vim.opt.runtimepath:append(path)
        break
    end
end

-- Set up 'mini.test' only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() == 0 then
    -- Add 'mini.nvim' to 'runtimepath' to be able to use 'mini.test'
    -- Assumed that 'mini.nvim' is stored in 'deps/mini.nvim'
    vim.cmd "set rtp+=deps/mini.nvim"

    -- Set up 'mini.test'
    require("mini.test").setup()
end
