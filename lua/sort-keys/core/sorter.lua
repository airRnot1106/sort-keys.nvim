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
    --- @type ContainerInfo
    return {
        node = node,
        type = node:type(),
        start_row = start_row,
        end_row = end_row,
        start_col = start_col,
        end_col = end_col,
        is_multiline = start_row ~= end_row,
    }
end

--- Sort a single container
--- @param container TSNode
--- @param adapter AdapterInterface
--- @param flags ParsedFlags
--- @param reverse boolean
--- @param bufnr number
--- @return boolean success
local function sort_container(container, adapter, flags, reverse, bufnr)
    local container_info = get_container_info(container)

    -- Extract elements
    local elements = adapter.extract_elements(container, bufnr)

    if #elements == 0 then
        return true -- Nothing to sort
    end

    -- Remove duplicates if requested
    if flags.unique then
        elements = comparator.remove_duplicates(elements, flags.case_insensitive)
    end

    -- Create comparator and sort
    local compare_fn = comparator.create_comparator(flags, reverse)
    elements = comparator.sort_with_exclusions(elements, compare_fn)

    -- Format output
    local output_lines = adapter.format_output(elements, container_info, bufnr)

    if #output_lines == 0 then
        return true
    end

    -- Get the content area (inside the brackets/braces)
    local original_lines = text_utils.get_lines(bufnr, container_info.start_row, container_info.end_row)

    if container_info.is_multiline then
        -- For multi-line containers, replace the content between first and last lines
        local first_line = original_lines[1]
        local last_line = original_lines[#original_lines]

        -- Find the opening bracket position
        local open_bracket_col = first_line:find "[%{%[%(]"
        local close_bracket_col = last_line:find "[%}%]%)]"

        if open_bracket_col and close_bracket_col then
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
        end
    else
        -- For single-line containers, reconstruct the whole line
        local line = original_lines[1]
        local open_bracket_col = line:find "[%{%[%(]"
        local close_bracket_col = line:find "[%}%]%)]"

        if open_bracket_col and close_bracket_col then
            local prefix = line:sub(1, open_bracket_col)
            local suffix = line:sub(close_bracket_col)

            -- Join output for single line
            local content = output_lines[1] or ""
            local new_line = prefix .. " " .. content .. " " .. suffix

            text_utils.set_lines(bufnr, container_info.start_row, container_info.start_row, { new_line })
        end
    end

    return true
end

--- Sort keys in the buffer
--- @param opts SortKeysOptions
--- @return boolean success, string|nil error
function M.sort(opts)
    opts = opts or {}
    local bufnr = vim.api.nvim_get_current_buf()

    -- Get the language and adapter
    local lang = ts_utils.get_language(bufnr)
    if not lang then
        return false, "No tree-sitter parser available for this buffer"
    end

    local adapter = adapters.get_adapter(lang)
    if not adapter then
        return false, string.format("No adapter available for language: %s", lang)
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

    if opts.range then
        -- Sort all containers in range
        local start_row = opts.range[1] - 1 -- Convert to 0-indexed
        local end_row = opts.range[2] - 1
        containers = ts_utils.find_containers_in_range(bufnr, start_row, end_row, container_types)

        -- Filter to only top-level containers (not nested within other found containers)
        local top_level = {}
        for _, container in ipairs(containers) do
            local is_nested = false
            for _, other in ipairs(containers) do
                if container ~= other then
                    local c_start, _, c_end, _ = container:range()
                    local o_start, _, o_end, _ = other:range()
                    if c_start >= o_start and c_end <= o_end then
                        is_nested = true
                        break
                    end
                end
            end
            if not is_nested then
                table.insert(top_level, container)
            end
        end
        containers = top_level
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
            -- Deep sort: sort nested containers first (bottom-up)
            local nested = ts_utils.find_containers_in_range(
                bufnr,
                container:range(),
                select(3, container:range()),
                container_types
            )
            -- Sort by depth (deepest first)
            table.sort(nested, function(a, b)
                local a_start = a:range()
                local b_start = b:range()
                return a_start > b_start
            end)

            for _, nested_container in ipairs(nested) do
                sort_container(nested_container, adapter, flags, opts.reverse or false, bufnr)
            end
        else
            sort_container(container, adapter, flags, opts.reverse or false, bufnr)
        end
    end

    return true, nil
end

return M
