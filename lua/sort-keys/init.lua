---sort-keys.nvim - Sort object keys using Treesitter
---@class SortKeysModule
local M = {}

local config = require "sort-keys.config"
local adapters = require "sort-keys.adapters"
local commands = require "sort-keys.commands"

---Setup the plugin with user configuration
---@param opts? SortKeysPartialConfig
function M.setup(opts)
    opts = opts or {}
    config.setup(opts)
    config.apply_custom_adapters(adapters.register)
end

---Sort keys in the current buffer
---@param opts? SortKeysOptions
function M.sort_keys(opts)
    commands.sort_keys(opts or {}, nil)
end

---Deep sort keys in the current buffer (recursive)
---@param opts? SortKeysOptions
function M.deep_sort_keys(opts)
    opts = opts or {}
    opts.deep = true
    commands.sort_keys(opts, nil)
end

---Register a custom adapter
---@param adapter SortKeysAdapter
function M.register_adapter(adapter)
    adapters.register(adapter)
end

---Get list of supported filetypes
---@return string[]
function M.get_supported_filetypes()
    return adapters.get_supported_filetypes()
end

return M
