--- Text manipulation utilities for sort-keys.nvim
local M = {}

--- Get the indentation of a line
--- @param line string
--- @return string The leading whitespace
function M.get_indent(line)
    return line:match "^(%s*)" or ""
end

--- Get lines from buffer
--- @param bufnr number Buffer number
--- @param start_row number 0-indexed start row
--- @param end_row number 0-indexed end row (inclusive)
--- @return string[]
function M.get_lines(bufnr, start_row, end_row)
    return vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
end

--- Set lines in buffer
--- @param bufnr number Buffer number
--- @param start_row number 0-indexed start row
--- @param end_row number 0-indexed end row (inclusive)
--- @param lines string[]
function M.set_lines(bufnr, start_row, end_row, lines)
    vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, lines)
end

--- Strip quotes from a string
--- @param str string
--- @return string
function M.strip_quotes(str)
    return str:gsub("^[\"']", ""):gsub("[\"']$", "")
end

--- Trim whitespace from both ends of a string
--- @param str string
--- @return string
function M.trim(str)
    return str:match "^%s*(.-)%s*$"
end

--- Check if a string is empty or only whitespace
--- @param str string
--- @return boolean
function M.is_blank(str)
    return str:match "^%s*$" ~= nil
end

--- Split a string by a delimiter
--- @param str string
--- @param delimiter string
--- @return string[]
function M.split(str, delimiter)
    local result = {}
    for part in str:gmatch("([^" .. delimiter .. "]+)") do
        table.insert(result, part)
    end
    return result
end

--- Join strings with a delimiter
--- @param strings string[]
--- @param delimiter string
--- @return string
function M.join(strings, delimiter)
    return table.concat(strings, delimiter)
end

--- Detect the base indentation level from a set of lines
--- @param lines string[]
--- @return string The minimum common indentation
function M.detect_base_indent(lines)
    local min_indent = nil
    for _, line in ipairs(lines) do
        if not M.is_blank(line) then
            local indent = M.get_indent(line)
            if min_indent == nil or #indent < #min_indent then
                min_indent = indent
            end
        end
    end
    return min_indent or ""
end

--- Increase indentation of a line
--- @param line string
--- @param indent string Additional indent to add
--- @return string
function M.add_indent(line, indent)
    return indent .. line
end

--- Extract trailing separator from text
--- @param text string
--- @param separator string Expected separator (e.g., ",", ";")
--- @return string text_without_sep, string|nil trailing_sep
function M.extract_trailing_separator(text, separator)
    local pattern = "(%s*)" .. vim.pesc(separator) .. "(%s*)$"
    local ws_before, _ = text:match(pattern)
    if ws_before then
        local text_without = text:gsub(pattern, "")
        return text_without, separator
    end
    return text, nil
end

--- Check if text ends with separator
--- @param text string
--- @param separator string
--- @return boolean
function M.has_trailing_separator(text, separator)
    local trimmed = M.trim(text)
    return trimmed:sub(-#separator) == separator
end

--- Append separator to text if not already present
--- @param text string
--- @param separator string
--- @return string
function M.ensure_trailing_separator(text, separator)
    local trimmed = M.trim(text)
    if trimmed:sub(-#separator) == separator then
        return text
    end
    return trimmed .. separator
end

--- Remove trailing separator from text
--- @param text string
--- @param separator string
--- @return string
function M.remove_trailing_separator(text, separator)
    local trimmed = M.trim(text)
    if trimmed:sub(-#separator) == separator then
        return trimmed:sub(1, -#separator - 1)
    end
    return text
end

return M
