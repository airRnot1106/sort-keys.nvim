---@class SortKeysConfigModule
---@field config SortKeysConfig
local M = {}

---@type SortKeysConfig
M.config = {
    default_options = {
        reverse = false,
        deep = false,
        case_sensitive = true,
        natural_sort = false,
    },
    custom_adapters = {},
}

---Setup configuration with user options
---@param opts? SortKeysPartialConfig
function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

---Apply user-defined custom adapters to the adapter registry.
---@param register fun(adapter: SortKeysAdapter)
function M.apply_custom_adapters(register)
    local custom_adapters = M.config.custom_adapters
    for _, adapter in ipairs(custom_adapters) do
        register(adapter)
    end
end

---Get merged options with defaults
---@param opts? SortKeysOptions
---@return SortKeysOptions
function M.get_options(opts)
    return vim.tbl_deep_extend("force", M.config.default_options, opts or {})
end

return M
