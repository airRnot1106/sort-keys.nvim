--- Comparison functions for sort-keys.nvim
local M = {}

--- Extract numeric value from string based on mode
--- @param str string
--- @param mode "decimal"|"float"|"hex"|"octal"|"binary"
--- @return number|nil
local function extract_number(str, mode)
    if not str then
        return nil
    end

    if mode == "decimal" then
        -- Match integer (with optional sign)
        local num = str:match "%-?%d+"
        return num and tonumber(num)
    elseif mode == "float" then
        -- Match floating point (with optional sign and decimal)
        local num = str:match "%-?%d+%.?%d*" or str:match "%-?%.%d+"
        return num and tonumber(num)
    elseif mode == "hex" then
        -- Match hexadecimal (with optional 0x prefix)
        local num = str:match "0[xX](%x+)" or str:match "(%x+)"
        return num and tonumber(num, 16)
    elseif mode == "octal" then
        -- Match octal (with optional 0o prefix)
        local num = str:match "0[oO]([0-7]+)" or str:match "([0-7]+)"
        return num and tonumber(num, 8)
    elseif mode == "binary" then
        -- Match binary (with optional 0b prefix)
        local num = str:match "0[bB]([01]+)" or str:match "([01]+)"
        return num and tonumber(num, 2)
    end

    return nil
end

--- Create a comparator function based on flags
--- @param flags ParsedFlags
--- @param reverse boolean
--- @return fun(a: ElementInfo, b: ElementInfo): boolean
function M.create_comparator(flags, reverse)
    return function(a, b)
        -- Get keys
        local key_a = a.key_text or ""
        local key_b = b.key_text or ""

        local result

        if flags.numeric_mode then
            -- Numeric comparison
            local num_a = extract_number(key_a, flags.numeric_mode)
            local num_b = extract_number(key_b, flags.numeric_mode)

            if num_a and num_b then
                result = num_a < num_b
            elseif num_a then
                -- a has number, b doesn't - a comes first
                result = true
            elseif num_b then
                -- b has number, a doesn't - b comes first
                result = false
            else
                -- Neither has number, fall back to string comparison
                if flags.case_insensitive then
                    result = key_a:lower() < key_b:lower()
                else
                    result = key_a < key_b
                end
            end
        else
            -- String comparison
            if flags.case_insensitive then
                result = key_a:lower() < key_b:lower()
            else
                result = key_a < key_b
            end
        end

        -- Reverse if needed
        if reverse then
            return not result
        end
        return result
    end
end

--- Remove duplicate elements (keeping first occurrence)
--- @param elements ElementInfo[]
--- @param case_insensitive boolean
--- @return ElementInfo[]
function M.remove_duplicates(elements, case_insensitive)
    local seen = {}
    local result = {}

    for _, elem in ipairs(elements) do
        local key = elem.key_text or elem.value_text
        if case_insensitive then
            key = key:lower()
        end

        if not seen[key] then
            seen[key] = true
            table.insert(result, elem)
        end
    end

    return result
end

--- Sort elements while preserving excluded elements in their original positions
--- @param elements ElementInfo[]
--- @param comparator fun(a: ElementInfo, b: ElementInfo): boolean
--- @return ElementInfo[]
function M.sort_with_exclusions(elements, comparator)
    -- Separate excluded and sortable elements
    local excluded_positions = {} -- index -> element
    local sortable = {}

    for i, elem in ipairs(elements) do
        if elem.is_excluded then
            excluded_positions[i] = elem
        else
            table.insert(sortable, elem)
        end
    end

    -- Sort the sortable elements
    table.sort(sortable, comparator)

    -- Reconstruct the list, putting excluded elements back in their original positions
    local result = {}
    local sortable_idx = 1

    for i = 1, #elements do
        if excluded_positions[i] then
            table.insert(result, excluded_positions[i])
        else
            table.insert(result, sortable[sortable_idx])
            sortable_idx = sortable_idx + 1
        end
    end

    return result
end

return M
