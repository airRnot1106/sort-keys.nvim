---Main sorting algorithm for sort-keys
local tree_utils = require "sort-keys.core.tree"

local M = {}

---Natural sort comparison - handles embedded numbers
---@param a string
---@param b string
---@return boolean
local function natural_compare(a, b)
    local function split_into_parts(str)
        local parts = {}
        local current = ""
        local is_num = false

        for i = 1, #str do
            local char = str:sub(i, i)
            local char_is_num = char:match "%d" ~= nil

            if i == 1 then
                is_num = char_is_num
                current = char
            elseif char_is_num == is_num then
                current = current .. char
            else
                table.insert(parts, { value = current, is_number = is_num })
                current = char
                is_num = char_is_num
            end
        end

        if #current > 0 then
            table.insert(parts, { value = current, is_number = is_num })
        end

        return parts
    end

    local parts_a = split_into_parts(a)
    local parts_b = split_into_parts(b)

    for i = 1, math.max(#parts_a, #parts_b) do
        local part_a = parts_a[i]
        local part_b = parts_b[i]

        if not part_a then
            return true
        end
        if not part_b then
            return false
        end

        if part_a.is_number and part_b.is_number then
            local num_a = tonumber(part_a.value)
            local num_b = tonumber(part_b.value)
            if num_a ~= num_b then
                return num_a < num_b
            end
        else
            if part_a.value ~= part_b.value then
                return part_a.value < part_b.value
            end
        end
    end

    return false
end

---Create comparison function based on options
---@param opts SortKeysOptions
---@return fun(a: SortKeysEntry, b: SortKeysEntry): boolean
local function create_comparator(opts)
    return function(a, b)
        local key_a = a.key
        local key_b = b.key

        if not opts.case_sensitive then
            key_a = key_a:lower()
            key_b = key_b:lower()
        end

        local result
        if opts.natural_sort then
            result = natural_compare(key_a, key_b)
        else
            result = key_a < key_b
        end

        if opts.reverse then
            return not result
        end
        return result
    end
end

---Extract entries from an object node
---@param object_node TSNode
---@param adapter SortKeysAdapter
---@param bufnr integer
---@return SortKeysEntry[]
local function extract_entries(object_node, adapter, bufnr)
    local entries = {}
    local comment_types = adapter.get_comment_node_types()
    local comment_type_set = {}
    for _, t in ipairs(comment_types) do
        comment_type_set[t] = true
    end

    local pending_comments = {}

    for child in object_node:iter_children() do
        local child_type = child:type()

        -- Collect comments
        if comment_type_set[child_type] then
            table.insert(pending_comments, tree_utils.get_node_text(child, bufnr))
        elseif adapter.is_sortable_entry(child) then
            local key = adapter.extract_key(child, bufnr)
            if key then
                local start_row, start_col, end_row, end_col = child:range()
                local entry = {
                    node = child,
                    key = key,
                    text = tree_utils.get_node_text(child, bufnr),
                    start_row = start_row,
                    start_col = start_col,
                    end_row = end_row,
                    end_col = end_col,
                    leading_comments = pending_comments,
                    trailing_comment = nil,
                }
                table.insert(entries, entry)
                pending_comments = {}
            end
        end
    end

    return entries
end

---Detect indentation from object node
---@param object_node TSNode
---@param bufnr integer
---@return string base_indent Base indentation for closing bracket
---@return string entry_indent Indentation for entries
local function detect_indentation(object_node, bufnr)
    local start_row, start_col, end_row, _ = object_node:range()
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)

    -- Base indent is the indentation of the opening bracket line
    local first_line = lines[1] or ""
    local base_indent = first_line:match "^(%s*)"

    -- Entry indent: look for the first entry's indentation
    local entry_indent = base_indent .. "  " -- Default: 2 spaces more than base
    if #lines > 2 then
        local second_line = lines[2]
        local detected = second_line:match "^(%s+)"
        if detected and #detected > #base_indent then
            entry_indent = detected
        end
    end

    return base_indent, entry_indent
end

---Check if entry text has trailing separator
---@param text string
---@param separator string
---@return boolean
local function has_trailing_separator(text, separator)
    return text:match(vim.pesc(separator) .. "%s*$") ~= nil
end

---Remove trailing separator from text
---@param text string
---@param separator string
---@return string
local function remove_trailing_separator(text, separator)
    return text:gsub(vim.pesc(separator) .. "%s*$", "")
end

---Add trailing separator to text
---@param text string
---@param separator string
---@return string
local function add_trailing_separator(text, separator)
    return text .. separator
end

---Reconstruct the sorted object text
---@param object_node TSNode
---@param sorted_entries SortKeysEntry[]
---@param adapter SortKeysAdapter
---@param bufnr integer
---@return string[]
local function reconstruct_object(object_node, sorted_entries, adapter, bufnr)
    local original_text = tree_utils.get_node_text(object_node, bufnr)
    local lines = vim.split(original_text, "\n", { plain = true })

    -- Handle inline objects (single line)
    if #lines == 1 then
        return reconstruct_inline_object(sorted_entries, adapter, original_text)
    end

    local base_indent, entry_indent = detect_indentation(object_node, bufnr)
    local separator = adapter.get_separator()

    -- Extract opening and closing brackets
    local opening = lines[1]:match "^%s*(.-)%s*$"
    local closing = lines[#lines]:match "^%s*(.-)%s*$"

    -- Build result
    local result = { opening }

    for i, entry in ipairs(sorted_entries) do
        -- Add leading comments
        for _, comment in ipairs(entry.leading_comments) do
            table.insert(result, entry_indent .. comment)
        end

        local entry_text = entry.text
        -- Normalize: remove existing trailing separator
        entry_text = remove_trailing_separator(entry_text, separator)

        -- Add separator if not the last entry
        if i < #sorted_entries then
            entry_text = add_trailing_separator(entry_text, separator)
        end

        -- Handle multi-line entries
        local entry_lines = vim.split(entry_text, "\n", { plain = true })
        -- The original start column tells us the indentation level of the first line
        -- get_node_text doesn't include first line's leading whitespace
        local original_first_line_indent = string.rep(" ", entry.start_col)
        for j, line in ipairs(entry_lines) do
            if j == 1 then
                table.insert(result, entry_indent .. line:match "^%s*(.-)%s*$")
            else
                -- Calculate relative indentation from original first line position
                local line_indent = line:match "^(%s*)" or ""
                local relative_indent = ""
                if #line_indent > #original_first_line_indent then
                    relative_indent = line_indent:sub(#original_first_line_indent + 1)
                end
                local trimmed = line:match "^%s*(.-)%s*$"
                if trimmed ~= "" then
                    table.insert(result, entry_indent .. relative_indent .. trimmed)
                else
                    table.insert(result, "")
                end
            end
        end
    end

    table.insert(result, base_indent .. closing)
    return result
end

---Reconstruct inline object (single line)
---@param sorted_entries SortKeysEntry[]
---@param adapter SortKeysAdapter
---@param original_text string
---@return string[]
function reconstruct_inline_object(sorted_entries, adapter, original_text)
    local separator = adapter.get_separator()

    -- Extract opening and closing brackets
    local opening = original_text:match "^(%s*{%s*)"
    local closing = original_text:match "(%s*}%s*)$"

    if not opening or not closing then
        -- Fallback for other bracket types
        opening = original_text:match "^(%s*[%[{(]%s*)" or "{ "
        closing = original_text:match "(%s*[%]})]%s*)$" or " }"
    end

    local parts = {}
    for i, entry in ipairs(sorted_entries) do
        local entry_text = remove_trailing_separator(entry.text:match "^%s*(.-)%s*$", separator)
        if i < #sorted_entries then
            entry_text = entry_text .. separator .. " "
        end
        table.insert(parts, entry_text)
    end

    return { opening .. table.concat(parts, "") .. closing }
end

---Sort a single object node
---@param bufnr integer
---@param object_node TSNode
---@param adapter SortKeysAdapter
---@param opts SortKeysOptions
local function sort_single_object(bufnr, object_node, adapter, opts)
    local entries = extract_entries(object_node, adapter, bufnr)

    -- Skip if less than 2 entries
    if #entries < 2 then
        return
    end

    -- Sort entries
    local comparator = create_comparator(opts)
    table.sort(entries, comparator)

    -- Reconstruct and replace
    local new_lines = reconstruct_object(object_node, entries, adapter, bufnr)
    local start_row, start_col, end_row, end_col = object_node:range()

    vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, new_lines)
end

---Sort with deep option (recursive)
---@param bufnr integer
---@param root_object TSNode
---@param adapter SortKeysAdapter
---@param opts SortKeysOptions
local function sort_deep(bufnr, root_object, adapter, opts)
    local sortable_types = adapter.get_sortable_node_types()

    -- Collect all nested sortable nodes including the root
    local all_objects = { root_object }
    local nested = tree_utils.collect_nested_sortable_nodes(root_object, sortable_types)
    for _, node in ipairs(nested) do
        table.insert(all_objects, node)
    end

    -- Sort by depth (deepest first) to avoid position shifts
    table.sort(all_objects, function(a, b)
        return tree_utils.get_node_depth(a) > tree_utils.get_node_depth(b)
    end)

    -- Sort each object, re-parsing after each modification
    for _, obj in ipairs(all_objects) do
        -- Re-parse to get updated tree
        local parser = tree_utils.get_parser(bufnr)
        if parser then
            parser:parse()
        end

        -- Find the object at the same position in the new tree
        local root = tree_utils.get_root(bufnr)
        if root then
            local obj_start_row, obj_start_col, _, _ = obj:range()
            local updated_obj =
                tree_utils.find_sortable_node_at_position(root, obj_start_row, obj_start_col, sortable_types)
            if updated_obj then
                sort_single_object(bufnr, updated_obj, adapter, opts)
            end
        end
    end
end

---Main sort function
---@param bufnr integer
---@param adapter SortKeysAdapter
---@param opts SortKeysOptions
---@param range? {start_row: integer, end_row: integer}
function M.sort(bufnr, adapter, opts, range)
    local root = tree_utils.get_root(bufnr)
    if not root then
        vim.notify("No Treesitter parser available for this buffer", vim.log.levels.ERROR)
        return
    end

    local sortable_types = adapter.get_sortable_node_types()
    local target_nodes = {}

    if range then
        -- Find all sortable nodes in range
        target_nodes = tree_utils.find_sortable_nodes_in_range(root, range.start_row, range.end_row, sortable_types)
    else
        -- Find sortable node at cursor
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = cursor[1] - 1 -- Convert to 0-indexed
        local col = cursor[2]
        local node = tree_utils.find_sortable_node_at_position(root, row, col, sortable_types)
        if node then
            target_nodes = { node }
        end
    end

    if #target_nodes == 0 then
        vim.notify("No sortable object found", vim.log.levels.INFO)
        return
    end

    -- Sort nodes from bottom to top to maintain positions
    table.sort(target_nodes, function(a, b)
        local a_row = a:range()
        local b_row = b:range()
        return a_row > b_row
    end)

    for _, target_node in ipairs(target_nodes) do
        if opts.deep then
            sort_deep(bufnr, target_node, adapter, opts)
        else
            sort_single_object(bufnr, target_node, adapter, opts)
        end
    end
end

return M
