--- Flag parsing for sort-keys.nvim
local M = {}

--- Parse sorting flags from command arguments
--- @param args string The flag string (e.g., "in", "f", "iu")
--- @return ParsedFlags
function M.parse_flags(args)
    --- @type ParsedFlags
    local flags = {
        case_insensitive = false,
        numeric_mode = nil,
        unique = false,
    }

    if not args or args == "" then
        return flags
    end

    -- Normalize the input (remove spaces, lowercase)
    local normalized = args:gsub("%s+", ""):lower()

    -- Parse each character
    for i = 1, #normalized do
        local char = normalized:sub(i, i)

        if char == "i" then
            flags.case_insensitive = true
        elseif char == "n" then
            flags.numeric_mode = "decimal"
        elseif char == "f" then
            flags.numeric_mode = "float"
        elseif char == "x" then
            flags.numeric_mode = "hex"
        elseif char == "o" then
            flags.numeric_mode = "octal"
        elseif char == "b" then
            flags.numeric_mode = "binary"
        elseif char == "u" then
            flags.unique = true
        end
    end

    return flags
end

--- Validate that flags are compatible
--- @param flags ParsedFlags
--- @return boolean is_valid, string|nil error_message
function M.validate_flags(_flags)
    -- Currently no validation needed as numeric modes just overwrite each other
    -- This function is for future extensibility
    return true, nil
end

--- Parse range from command
--- @param range_start number|nil Command range start (1-indexed)
--- @param range_end number|nil Command range end (1-indexed)
--- @return { [1]: number, [2]: number }|nil 1-indexed line range
function M.parse_range(range_start, range_end)
    if not range_start or not range_end then
        return nil
    end

    -- Vim ranges are 1-indexed, keep them as-is
    return { range_start, range_end }
end

return M
