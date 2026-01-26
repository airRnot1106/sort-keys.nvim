local M = {}

-- Initialize sort-keys plugin (load commands)
vim.cmd "runtime plugin/sort-keys.lua"

-- Map filetype to tree-sitter language
local filetype_to_lang = {
    javascript = "javascript",
    typescript = "typescript",
    json = "json",
    jsonc = "json", -- jsonc uses json parser
    lua = "lua",
}

--- Create a buffer with content and filetype, run command, return result
---@param content string The initial buffer content
---@param filetype string The filetype to set
---@param command string The command to execute (e.g., "SortKeys", "SortKeys!", "DeepSortKeys")
---@param range? {start_line: number, end_line: number} Optional range for the command
---@return string[] lines The resulting buffer lines
function M.run_sort(content, filetype, command, range)
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)

    -- Set content
    local lines = vim.split(content, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Set filetype
    vim.bo[buf].filetype = filetype

    -- Get tree-sitter language
    local lang = filetype_to_lang[filetype] or filetype

    -- Start tree-sitter explicitly
    vim.treesitter.start(buf, lang)

    -- Parse the buffer
    local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    if ok and parser then
        parser:parse()
    end

    -- Move cursor inside the container
    local line_count = vim.api.nvim_buf_line_count(buf)
    if line_count > 1 then
        -- Multi-line: position cursor on line 2 (typically inside container)
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
    else
        -- Single-line: position cursor after the first bracket/brace
        local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
        local col = first_line:find "[%[%{%(]"
        vim.api.nvim_win_set_cursor(0, { 1, col or 1 })
    end

    -- Build and execute command
    local cmd
    if range then
        cmd = string.format("%d,%d%s", range.start_line, range.end_line, command)
    else
        cmd = command
    end
    vim.cmd(cmd)

    -- Get result
    local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Cleanup
    vim.api.nvim_buf_delete(buf, { force = true })

    return result
end

--- Join lines into a single string
---@param lines string[]
---@return string
function M.join_lines(lines)
    return table.concat(lines, "\n")
end

return M
