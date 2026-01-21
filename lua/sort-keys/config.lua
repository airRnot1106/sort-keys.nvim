---@class SortKeysConfigModule
---@field options SortKeysConfig
local M = {}

---@type SortKeysConfig
M.options = {
    default_options = {
        reverse = false,
        deep = false,
        case_sensitive = true,
        natural_sort = false,
    },
}

---Setup configuration with user options
---@param opts? SortKeysConfig
function M.setup(opts)
    opts = opts or {}
    M.options = vim.tbl_deep_extend("force", M.options, opts)
end

---Get merged options with defaults
---@param opts? SortKeysOptions
---@return SortKeysOptions
function M.get_options(opts)
    return vim.tbl_deep_extend("force", M.options.default_options, opts or {})
end

return M
