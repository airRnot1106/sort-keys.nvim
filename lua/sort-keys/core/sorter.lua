--- Main sorting orchestrator for sort-keys.nvim
local ts_utils = require "sort-keys.utils.treesitter"
local text_utils = require "sort-keys.utils.text"
local parser = require "sort-keys.core.parser"
local comparator = require "sort-keys.core.comparator"
local adapters = require "sort-keys.adapters"

local M = {}

--- Get container info from a node
--- @param node TSNode
--- @return ContainerInfo
local function get_container_info(node)
    local start_row, start_col, end_row, end_col = node:range()

    -- Tree-sitter uses exclusive end position
    -- If end_col is 0, the node ends at the beginning of end_row (doesn't include end_row)
    -- Convert to inclusive end_row for our text utilities
    local inclusive_end_row = end_row
    if end_col == 0 and end_row > start_row then
        inclusive_end_row = end_row - 1
    end

    --- @type ContainerInfo
    return {
        node = node,
        type = node:type(),
        start_row = start_row,
        end_row = inclusive_end_row,
        start_col = start_col,
        end_col = end_col,
        is_multiline = start_row ~= inclusive_end_row,
    }
end

--- Check if a container's elements are already sorted
--- @param container TSNode
--- @param adapter AdapterInterface
--- @param flags ParsedFlags
--- @param reverse boolean
--- @param bufnr number
--- @return boolean is_sorted
local function is_container_sorted(container, adapter, flags, reverse, bufnr)
    local elements = adapter.extract_elements(container, bufnr)

    if #elements <= 1 then
        return true -- 0 or 1 element is already sorted
    end

    -- Filter out excluded elements for comparison
    local sortable_elements = {}
    for _, elem in ipairs(elements) do
        if not elem.is_excluded then
            table.insert(sortable_elements, elem)
        end
    end

    if #sortable_elements <= 1 then
        return true
    end

    -- Check if elements are in sorted order
    local compare_fn = comparator.create_comparator(flags, reverse)
    for i = 1, #sortable_elements - 1 do
        local a = sortable_elements[i]
        local b = sortable_elements[i + 1]
        -- If a should come after b, then it's not sorted
        if compare_fn(b, a) then
            return false
        end
    end

    return true
end

--- Sort a single container
--- @param container TSNode
--- @param adapter AdapterInterface
--- @param flags ParsedFlags
--- @param reverse boolean
--- @param bufnr number
--- @param range? { [1]: number, [2]: number } Optional range filter (0-indexed)
--- @return boolean success
local function sort_container(container, adapter, flags, reverse, bufnr, range)
    local container_info = get_container_info(container)

    -- Extract elements
    local elements = adapter.extract_elements(container, bufnr)

    if #elements == 0 then
        return true -- Nothing to sort
    end

    -- Check if the original last element had a trailing separator
    local had_trailing_separator = elements[#elements].separator ~= nil

    -- Filter elements by range if specified
    local elements_to_sort = {}
    local elements_before = {}
    local elements_after = {}

    if range then
        for _, elem in ipairs(elements) do
            if elem.end_row < range[1] then
                table.insert(elements_before, elem)
            elseif elem.start_row > range[2] then
                table.insert(elements_after, elem)
            else
                table.insert(elements_to_sort, elem)
            end
        end
    else
        elements_to_sort = elements
    end

    if #elements_to_sort == 0 then
        return true -- Nothing to sort in range
    end

    -- Remove duplicates if requested
    if flags.unique then
        elements_to_sort = comparator.remove_duplicates(elements_to_sort, flags.case_insensitive)
    end

    -- Create comparator and sort
    local compare_fn = comparator.create_comparator(flags, reverse)
    elements_to_sort = comparator.sort_with_exclusions(elements_to_sort, compare_fn)

    -- Reconstruct full element list
    local sorted_elements = {}
    for _, elem in ipairs(elements_before) do
        table.insert(sorted_elements, elem)
    end
    for _, elem in ipairs(elements_to_sort) do
        table.insert(sorted_elements, elem)
    end
    for _, elem in ipairs(elements_after) do
        table.insert(sorted_elements, elem)
    end

    -- Format output
    local output_lines = adapter.format_output(sorted_elements, container_info, bufnr, had_trailing_separator)

    if #output_lines == 0 then
        return true
    end

    -- Get the content area (inside the brackets/braces)
    local original_lines = text_utils.get_lines(bufnr, container_info.start_row, container_info.end_row)

    -- Check if this container type has brackets
    local open_bracket, close_bracket = adapter.get_brackets(container_info.type)
    local has_brackets = open_bracket ~= nil and close_bracket ~= nil

    if has_brackets then
        -- Container with brackets (e.g., {}, [], ())
        if container_info.is_multiline then
            -- For multi-line containers, replace the content between first and last lines
            local first_line = original_lines[1]
            local last_line = original_lines[#original_lines]

            -- Use container position to find the correct bracket (0-indexed to 1-indexed)
            local open_bracket_col = container_info.start_col + 1
            local close_bracket_col = container_info.end_col -- end_col points to the closing bracket

            -- Preserve the opening bracket and content before it
            local prefix = first_line:sub(1, open_bracket_col)

            -- Preserve the closing bracket and content after it
            local suffix = last_line:sub(close_bracket_col)

            -- Build the new content
            local new_lines = { prefix }
            for _, line in ipairs(output_lines) do
                table.insert(new_lines, line)
            end
            -- Add closing bracket on its own line with proper indentation
            local base_indent = text_utils.get_indent(first_line)
            new_lines[#new_lines + 1] = base_indent .. suffix

            -- Replace the container content
            text_utils.set_lines(bufnr, container_info.start_row, container_info.end_row, new_lines)
        else
            -- For single-line containers, reconstruct the whole line
            local line = original_lines[1]
            -- Use container position to find the correct bracket (0-indexed to 1-indexed)
            local open_bracket_col = container_info.start_col + 1
            local close_bracket_col = container_info.end_col

            local prefix = line:sub(1, open_bracket_col)
            local suffix = line:sub(close_bracket_col)

            -- Join output for single line
            local content = output_lines[1] or ""
            local new_line = prefix .. content .. suffix

            text_utils.set_lines(bufnr, container_info.start_row, container_info.start_row, { new_line })
        end
    else
        -- Container without brackets (e.g., YAML block_mapping, block_sequence)
        -- Replace the entire container range with the output
        text_utils.set_lines(bufnr, container_info.start_row, container_info.end_row, output_lines)
    end

    return true
end

--- Sort keys in the buffer
--- @param opts SortKeysOptions
--- @return boolean success, string|nil error
function M.sort(opts)
    opts = opts or {}
    local bufnr = vim.api.nvim_get_current_buf()

    -- Get the filetype and adapter
    local filetype = vim.bo[bufnr].filetype
    if filetype == "" then
        return false, "No filetype detected for this buffer"
    end

    -- Check tree-sitter parser is available
    if not ts_utils.get_parser(bufnr) then
        return false, "No tree-sitter parser available for this buffer"
    end

    local adapter = adapters.get_adapter(filetype)
    if not adapter then
        return false, string.format("No adapter available for filetype: %s", filetype)
    end

    -- Parse flags
    local flags = parser.parse_flags(opts.flags or "")
    local is_valid, err = parser.validate_flags(flags)
    if not is_valid then
        return false, err
    end

    -- Find containers to sort
    local containers = {}
    local container_types = adapter.get_container_types()
    local range_filter = nil -- 0-indexed range for filtering elements

    if opts.range then
        -- Sort all containers in range
        local start_row = opts.range[1] - 1 -- Convert to 0-indexed
        local end_row = opts.range[2] - 1
        range_filter = { start_row, end_row }
        local all_containers = ts_utils.find_containers_in_range(bufnr, start_row, end_row, container_types)

        -- Find the smallest container that fully contains the range
        -- This is the innermost container that contains all selected lines
        local smallest = nil
        local smallest_size = math.huge
        for _, container in ipairs(all_containers) do
            local c_start, _, c_end, _ = container:range()
            -- Container must contain the entire range
            if c_start <= start_row and c_end >= end_row then
                local size = c_end - c_start
                if size < smallest_size then
                    smallest = container
                    smallest_size = size
                end
            end
        end

        if smallest then
            containers = { smallest }
        end
    else
        -- Find container at cursor
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = cursor[1] - 1 -- Convert to 0-indexed
        local col = cursor[2]
        local container = ts_utils.find_container_at_position(bufnr, row, col, container_types)
        if container then
            containers = { container }
        end
    end

    if #containers == 0 then
        return false, "No sortable container found"
    end

    -- Sort containers (in reverse order to preserve line numbers)
    table.sort(containers, function(a, b)
        local a_start = a:range()
        local b_start = b:range()
        return a_start > b_start
    end)

    -- Process each container
    for _, container in ipairs(containers) do
        if opts.deep then
            -- Deep sort: sort nested containers one at a time, re-parsing after each sort
            -- This is necessary because after sorting a container, the tree-sitter nodes
            -- for other containers become invalid (they reference old buffer positions)
            local c_start_row, _, c_end_row, _ = container:range()
            local max_iterations = 1000 -- Safety limit to prevent infinite loops
            local iterations = 0

            while iterations < max_iterations do
                iterations = iterations + 1

                -- Re-parse to get fresh container nodes after each sort
                local all_containers = ts_utils.find_containers_in_range(bufnr, c_start_row, c_end_row, container_types)

                -- Filter to only include containers fully contained within the original range
                -- This prevents sorting parent containers that merely overlap with the range
                local nested = {}
                for _, c in ipairs(all_containers) do
                    local cs, _, ce, _ = c:range()
                    if cs >= c_start_row and ce <= c_end_row then
                        table.insert(nested, c)
                    end
                end

                -- Sort by depth (deepest first - higher start row means deeper nesting)
                table.sort(nested, function(a, b)
                    local a_start = a:range()
                    local b_start = b:range()
                    return a_start > b_start
                end)

                -- Find the first unsorted container
                local unsorted_container = nil
                for _, nested_container in ipairs(nested) do
                    if not is_container_sorted(nested_container, adapter, flags, opts.reverse or false, bufnr) then
                        unsorted_container = nested_container
                        break
                    end
                end

                if not unsorted_container then
                    -- All containers are sorted, we're done
                    break
                end

                -- Sort this container
                sort_container(unsorted_container, adapter, flags, opts.reverse or false, bufnr, range_filter)
            end
        else
            sort_container(container, adapter, flags, opts.reverse or false, bufnr, range_filter)
        end
    end

    return true, nil
end

return M
