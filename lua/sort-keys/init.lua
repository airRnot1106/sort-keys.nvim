--- sort-keys.nvim - Sort object/table/array keys using tree-sitter
--- @module sort-keys

local sorter = require "sort-keys.core.sorter"
local adapters = require "sort-keys.adapters"

local M = {}

--- @class SortKeysConfig
--- @field custom_adapters? table<string, AdapterInterface> Custom adapters for languages

--- Setup the plugin
--- @param opts? SortKeysConfig
function M.setup(opts)
    opts = opts or {}

    -- Register custom adapters
    if opts.custom_adapters then
        for lang, adapter in pairs(opts.custom_adapters) do
            adapters.register(lang, adapter)
        end
    end
end

--- Sort keys in the current buffer
--- @param opts? SortKeysOptions
--- @return boolean success
function M.sort_keys(opts)
    opts = opts or {}
    opts.deep = false

    local success, err = sorter.sort(opts)

    if not success then
        vim.notify("SortKeys: " .. (err or "Unknown error"), vim.log.levels.ERROR)
    end

    return success
end

--- Recursively sort keys in nested containers
--- @param opts? SortKeysOptions
--- @return boolean success
function M.deep_sort_keys(opts)
    opts = opts or {}
    opts.deep = true

    local success, err = sorter.sort(opts)

    if not success then
        vim.notify("DeepSortKeys: " .. (err or "Unknown error"), vim.log.levels.ERROR)
    end

    return success
end

--- Register a custom adapter for a language
--- @param lang string Language name
--- @param adapter AdapterInterface
function M.register_adapter(lang, adapter)
    adapters.register(lang, adapter)
end

--- Get supported languages
--- @return string[]
function M.get_supported_languages()
    return adapters.get_supported_languages()
end

return M
