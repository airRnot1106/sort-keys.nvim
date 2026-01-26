--- Base adapter factory for sort-keys.nvim
--- Creates adapters from configuration data
local ts_utils = require "sort-keys.utils.treesitter"
local text_utils = require "sort-keys.utils.text"

local M = {}

--- Create an adapter from configuration
--- @param config AdapterConfig Language-specific configuration
--- @return AdapterInterface Generated adapter
function M.create(config)
    local adapter = {}

    --- Get filetypes that this adapter handles
    --- @return string[]
    function adapter.get_filetypes()
        return config.filetypes or {}
    end

    --- Get container types for this language
    --- @return string[]
    function adapter.get_container_types()
        return config.container_types
    end

    --- Get the separator for a container type
    --- @param container_type string
    --- @return string
    function adapter.get_separator(container_type)
        return config.separators[container_type] or ","
    end

    --- Get the element wrapper node type (intermediate node between container and elements)
    --- @param container_type string
    --- @return string|nil
    function adapter.get_element_wrapper(container_type)
        if config.element_wrappers then
            return config.element_wrappers[container_type]
        end
        return nil
    end

    --- Get the element type for a container
    --- @param container_type string
    --- @return string|nil
    function adapter.get_element_type(container_type)
        return config.element_types[container_type]
    end

    --- Check if a node should be excluded from sorting
    --- @param node TSNode
    --- @return boolean
    function adapter.is_excluded_element(node)
        if not config.exclude_types then
            return false
        end
        return vim.tbl_contains(config.exclude_types, node:type())
    end

    --- Get the sort key from an element
    --- @param element TSNode
    --- @param bufnr number
    --- @return string|nil
    adapter.get_key_from_element = config.get_key_from_element

    --- Collect leading comments for a node
    --- @param node TSNode
    --- @param bufnr number
    --- @return string[]
    local function collect_leading_comments(node, bufnr)
        local comments = {}
        local prev = node:prev_sibling()

        while prev and ts_utils.is_comment(prev) do
            local comment_start_row = prev:range()

            -- Check if this comment might be a trailing comment for another element
            local prev_prev = prev:prev_sibling()
            -- Skip separators and other unnamed nodes
            while prev_prev and not prev_prev:named() do
                prev_prev = prev_prev:prev_sibling()
            end

            -- If there's a previous element and the comment is on the same line,
            -- this is a trailing comment for that element, not our leading comment
            if prev_prev and not ts_utils.is_comment(prev_prev) then
                local _, _, prev_elem_end_row, _ = prev_prev:range()
                if comment_start_row == prev_elem_end_row then
                    break
                end
            end

            table.insert(comments, 1, ts_utils.get_node_text(prev, bufnr))
            prev = prev:prev_sibling()
        end

        return comments
    end

    --- Collect trailing comment on the same line as the node
    --- @param node TSNode
    --- @param bufnr number
    --- @param separator string
    --- @return string|nil
    local function collect_trailing_comment(node, bufnr, separator)
        local _, _, end_row, _ = node:range()

        -- Look for comment after the element (possibly after separator)
        local next_sib = node:next_sibling()

        -- Skip separator if present
        if next_sib and not next_sib:named() then
            local sib_text = ts_utils.get_node_text(next_sib, bufnr)
            local trimmed = text_utils.trim(sib_text)
            if separator ~= "" and (trimmed == separator or trimmed:find(vim.pesc(separator), 1, true)) then
                next_sib = next_sib:next_sibling()
            end
        end

        -- Check if next sibling is a comment on the same line
        if next_sib and ts_utils.is_comment(next_sib) then
            local comment_start_row = next_sib:range()
            if comment_start_row == end_row then
                return ts_utils.get_node_text(next_sib, bufnr)
            end
        end

        return nil
    end

    --- Extract elements from a container
    --- @param container TSNode
    --- @param bufnr number
    --- @return ElementInfo[]
    function adapter.extract_elements(container, bufnr)
        local elements = {}
        local container_type = container:type()
        local element_type = adapter.get_element_type(container_type)
        local wrapper_type = adapter.get_element_wrapper(container_type)
        local separator = adapter.get_separator(container_type)

        -- Find the node that contains the elements
        local element_parent = container
        if wrapper_type then
            for child in container:iter_children() do
                if child:type() == wrapper_type then
                    element_parent = child
                    break
                end
            end
        end

        -- Collect all children
        local children = {}
        for child in element_parent:iter_children() do
            if child:named() then
                table.insert(children, child)
            end
        end

        -- Process each child
        for _, child in ipairs(children) do
            -- Skip if we have a specific element type and this doesn't match
            local should_process = true

            -- Always skip comment nodes (they are handled via leading_comments)
            if ts_utils.is_comment(child) then
                should_process = false
            elseif element_type and child:type() ~= element_type then
                -- Skip non-matching types
                should_process = false
            end

            if should_process then
                local start_row, _, end_row, _ = child:range()
                local node_text = ts_utils.get_node_text(child, bufnr)
                local leading_comments = collect_leading_comments(child, bufnr)
                local trailing_comment = collect_trailing_comment(child, bufnr, separator)

                -- Get the line to extract indentation
                local lines = text_utils.get_lines(bufnr, start_row, start_row)
                local indent = ""
                if #lines > 0 then
                    indent = text_utils.get_indent(lines[1])
                end

                -- Extract trailing separator
                local value_text = node_text
                local trailing_sep = nil

                -- Check for separator after the element (as a sibling node)
                local next_sibling = child:next_sibling()
                if next_sibling and not next_sibling:named() then
                    local sib_text = ts_utils.get_node_text(next_sibling, bufnr)
                    local trimmed = text_utils.trim(sib_text)
                    -- Check if the sibling is the separator (possibly with surrounding whitespace)
                    if trimmed == separator or trimmed:find(vim.pesc(separator), 1, true) then
                        trailing_sep = separator
                    end
                end

                -- Also check if the value_text itself ends with the separator
                if not trailing_sep and separator ~= "" then
                    if text_utils.has_trailing_separator(value_text, separator) then
                        trailing_sep = separator
                    end
                end

                -- Get key from element
                local key_text = adapter.get_key_from_element(child, bufnr)

                -- Element is excluded if:
                -- 1. It's in the exclude_types list, OR
                -- 2. The key extraction returned nil (e.g., vararg, spread)
                local is_excluded = adapter.is_excluded_element(child) or (key_text == nil)

                --- @type ElementInfo
                local element_info = {
                    node = child,
                    key_text = key_text,
                    value_text = value_text,
                    start_row = start_row,
                    end_row = end_row,
                    leading_comments = leading_comments,
                    trailing_comment = trailing_comment,
                    separator = trailing_sep,
                    is_excluded = is_excluded,
                    indent = indent,
                }

                table.insert(elements, element_info)
            end
        end

        return elements
    end

    --- Format sorted elements back into text
    --- @param elements ElementInfo[]
    --- @param container ContainerInfo
    --- @param bufnr number
    --- @param had_trailing_separator boolean Whether the original last element had a trailing separator
    --- @return string[]
    function adapter.format_output(elements, container, _bufnr, had_trailing_separator)
        if #elements == 0 then
            return {}
        end

        local separator = adapter.get_separator(container.type)
        local is_multiline = container.is_multiline
        local lines = {}

        if is_multiline then
            -- Multi-line formatting
            for i, elem in ipairs(elements) do
                -- Add leading comments
                for _, comment in ipairs(elem.leading_comments) do
                    table.insert(lines, elem.indent .. comment)
                end

                -- Add the element
                local elem_text = elem.value_text
                local is_last = (i == #elements)

                -- Handle separator
                if separator ~= "" then
                    -- Remove any existing trailing separator
                    elem_text = text_utils.remove_trailing_separator(elem_text, separator)

                    -- Add separator: always for non-last, for last only if original had trailing separator
                    if not is_last or had_trailing_separator then
                        elem_text = elem_text .. separator
                    end
                end

                -- Add trailing comment if present
                if elem.trailing_comment then
                    elem_text = elem_text .. " " .. elem.trailing_comment
                end

                -- Handle multi-line elements
                local elem_lines = vim.split(elem_text, "\n", { plain = true })
                for j, line in ipairs(elem_lines) do
                    if j == 1 then
                        table.insert(lines, elem.indent .. line)
                    else
                        table.insert(lines, line)
                    end
                end
            end
        else
            -- Single-line formatting
            local parts = {}
            for i, elem in ipairs(elements) do
                -- Comments in single-line containers are kept inline
                local part = elem.value_text
                local is_last = (i == #elements)

                if separator ~= "" then
                    part = text_utils.remove_trailing_separator(part, separator)
                    if not is_last or had_trailing_separator then
                        part = part .. separator
                    end
                end

                -- Add trailing comment if present
                if elem.trailing_comment then
                    part = part .. " " .. elem.trailing_comment
                end

                table.insert(parts, part)
            end

            -- Join with appropriate spacing
            local join_sep = separator == "" and " " or " "
            table.insert(lines, table.concat(parts, join_sep))
        end

        return lines
    end

    return adapter
end

return M
