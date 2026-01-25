--- sort-keys.nvim - Sort object/table/array keys using tree-sitter
--- @module sort-keys

local sorter = require "sort-keys.core.sorter"
local adapters = require "sort-keys.adapters"

local M = {}

--- @class SortKeysConfig
--- @field notify_on_success? boolean Show notification on successful sort (default: false)
--- @field notify_on_error? boolean Show notification on error (default: true)

--- @type SortKeysConfig
local config = {
    notify_on_success = false,
    notify_on_error = true,
}

--- Setup the plugin
--- @param opts? SortKeysConfig
function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
end

--- Sort keys in the current buffer
--- @param opts? SortKeysOptions
--- @return boolean success
function M.sort_keys(opts)
    opts = opts or {}
    opts.deep = false

    local success, err = sorter.sort(opts)

    if not success and config.notify_on_error then
        vim.notify("SortKeys: " .. (err or "Unknown error"), vim.log.levels.ERROR)
    elseif success and config.notify_on_success then
        vim.notify("SortKeys: Sorted successfully", vim.log.levels.INFO)
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

    if not success and config.notify_on_error then
        vim.notify("DeepSortKeys: " .. (err or "Unknown error"), vim.log.levels.ERROR)
    elseif success and config.notify_on_success then
        vim.notify("DeepSortKeys: Sorted successfully", vim.log.levels.INFO)
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
