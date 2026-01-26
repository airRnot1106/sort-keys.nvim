--- Command registration for sort-keys.nvim
if vim.g.loaded_sort_keys then
    return
end
vim.g.loaded_sort_keys = true

local sort_keys = require "sort-keys"

--- Parse command arguments
--- @param args string Command arguments
--- @return string flags
local function parse_command_args(args)
    local flags = ""

    -- Split args by whitespace
    for arg in args:gmatch "%S+" do
        -- Each arg is a flag or combination of flags
        flags = flags .. arg
    end

    return flags
end

--- Create SortKeys command handler
--- @param opts table Command options from nvim_create_user_command
--- @param deep boolean Whether to do deep sorting
local function sort_command_handler(opts, deep)
    local flags = parse_command_args(opts.args)
    local reverse = opts.bang

    --- @type SortKeysOptions
    local sort_opts = {
        flags = flags,
        reverse = reverse,
        deep = deep,
    }

    -- Handle range
    if opts.range > 0 then
        sort_opts.range = { opts.line1, opts.line2 }
    end

    sort_keys.sort_keys(sort_opts)
end

-- Register commands
vim.api.nvim_create_user_command("SortKeys", function(opts)
    sort_command_handler(opts, false)
end, {
    nargs = "*",
    bang = true,
    range = true,
    desc = "Sort object/table/array keys",
})

vim.api.nvim_create_user_command("DeepSortKeys", function(opts)
    sort_command_handler(opts, true)
end, {
    nargs = "*",
    bang = true,
    range = true,
    desc = "Recursively sort object/table/array keys",
})
