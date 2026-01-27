-- Test helpers for sort-keys.nvim
-- Uses child process approach as recommended by mini.test

local Helpers = {}

--- Create a new child neovim instance with sort-keys setup
---@return table child The child neovim instance
function Helpers.new_child_neovim()
    local child = MiniTest.new_child_neovim()

    --- Setup the child process with sort-keys plugin loaded
    child.setup = function()
        child.restart { "-u", "scripts/minimal_init.lua" }

        -- Load sort-keys plugin
        child.lua [[vim.cmd('runtime plugin/sort-keys.lua')]]
    end

    return child
end

--- Run sort command in child process and return result
---@param child table The child neovim instance
---@param content string The initial buffer content
---@param filetype string The filetype to set
---@param command string The command to execute (e.g., "SortKeys", "SortKeys!", "DeepSortKeys")
---@return string result The resulting buffer content as a single string
function Helpers.run_sort(child, content, filetype, command)
    -- Map filetype to tree-sitter language
    local filetype_to_lang = {
        javascript = "javascript",
        typescript = "typescript",
        json = "json",
        jsonc = "json",
        lua = "lua",
        nix = "nix",
        yaml = "yaml",
    }

    local lang = filetype_to_lang[filetype] or filetype

    -- Create buffer with content in child process
    child.lua(
        [[
        local content, filetype, lang = ...
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)

        -- Set content
        local lines = vim.split(content, "\n", { plain = true })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        -- Set filetype
        vim.bo[buf].filetype = filetype

        -- Start tree-sitter
        vim.treesitter.start(buf, lang)

        -- Parse the buffer
        local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
        if ok and parser then
            parser:parse()
        end

        -- Position cursor inside the container
        local line_count = vim.api.nvim_buf_line_count(buf)
        if line_count > 1 then
            vim.api.nvim_win_set_cursor(0, { 2, 0 })
        else
            local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
            local col = first_line:find("[%[%{%(]")
            vim.api.nvim_win_set_cursor(0, { 1, col or 1 })
        end
    ]],
        { content, filetype, lang }
    )

    -- Execute sort command
    child.cmd(command)

    -- Get result
    local lines = child.lua_get [[vim.api.nvim_buf_get_lines(0, 0, -1, false)]]

    return table.concat(lines, "\n")
end

return Helpers
