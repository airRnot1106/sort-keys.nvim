--- Tree-sitter utilities for sort-keys.nvim
local M = {}

--- Get the tree-sitter parser for the current buffer
--- @param bufnr number Buffer number
--- @return vim.treesitter.LanguageTree|nil
function M.get_parser(bufnr)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not ok or not parser then
        return nil
    end
    return parser
end

--- Get the root node for the buffer
--- @param bufnr number Buffer number
--- @return TSNode|nil
function M.get_root(bufnr)
    local parser = M.get_parser(bufnr)
    if not parser then
        return nil
    end
    local tree = parser:parse()[1]
    if not tree then
        return nil
    end
    return tree:root()
end

--- Get the language of the buffer
--- @param bufnr number Buffer number
--- @return string|nil
function M.get_language(bufnr)
    local parser = M.get_parser(bufnr)
    if not parser then
        return nil
    end
    return parser:lang()
end

--- Find the smallest container node at the given position
--- @param bufnr number Buffer number
--- @param row number 0-indexed row
--- @param col number 0-indexed column
--- @param container_types string[] List of valid container type names
--- @return TSNode|nil
function M.find_container_at_position(bufnr, row, col, container_types)
    local root = M.get_root(bufnr)
    if not root then
        return nil
    end

    local node = root:named_descendant_for_range(row, col, row, col)
    if not node then
        return nil
    end

    -- Walk up the tree to find a container
    while node do
        if vim.tbl_contains(container_types, node:type()) then
            return node
        end
        node = node:parent()
    end

    return nil
end

--- Find all container nodes within a line range
--- @param bufnr number Buffer number
--- @param start_row number 0-indexed start row
--- @param end_row number 0-indexed end row (inclusive)
--- @param container_types string[] List of valid container type names
--- @return TSNode[]
function M.find_containers_in_range(bufnr, start_row, end_row, container_types)
    local root = M.get_root(bufnr)
    if not root then
        return {}
    end

    local containers = {}
    local visited = {}

    --- @param node TSNode
    local function traverse(node)
        local node_start_row, _, node_end_row, _ = node:range()

        -- Skip if node is completely outside the range
        if node_end_row < start_row or node_start_row > end_row then
            return
        end

        -- Check if this node is a container
        if vim.tbl_contains(container_types, node:type()) then
            local id = tostring(node:id())
            if not visited[id] then
                visited[id] = true
                table.insert(containers, node)
            end
        end

        -- Traverse children
        for child in node:iter_children() do
            traverse(child)
        end
    end

    traverse(root)
    return containers
end

--- Get the text of a node
--- @param node TSNode
--- @param bufnr number Buffer number
--- @return string
function M.get_node_text(node, bufnr)
    return vim.treesitter.get_node_text(node, bufnr)
end

--- Get node range as 0-indexed values
--- @param node TSNode
--- @return number start_row, number start_col, number end_row, number end_col
function M.get_node_range(node)
    return node:range()
end

--- Check if a node spans multiple lines
--- @param node TSNode
--- @return boolean
function M.is_multiline(node)
    local start_row, _, end_row, _ = node:range()
    return start_row ~= end_row
end

--- Get named children of a node
--- @param node TSNode
--- @return TSNode[]
function M.get_named_children(node)
    local children = {}
    for child in node:iter_children() do
        if child:named() then
            table.insert(children, child)
        end
    end
    return children
end

--- Get all children (named and unnamed) of a node
--- @param node TSNode
--- @return TSNode[]
function M.get_all_children(node)
    local children = {}
    for child in node:iter_children() do
        table.insert(children, child)
    end
    return children
end

--- Find child node by field name
--- @param node TSNode
--- @param field string Field name
--- @return TSNode|nil
function M.get_field(node, field)
    local children = node:field(field)
    if children and #children > 0 then
        return children[1]
    end
    return nil
end

--- Get the previous sibling node (including unnamed)
--- @param node TSNode
--- @return TSNode|nil
function M.get_prev_sibling(node)
    return node:prev_sibling()
end

--- Get the previous named sibling node
--- @param node TSNode
--- @return TSNode|nil
function M.get_prev_named_sibling(node)
    return node:prev_named_sibling()
end

--- Check if a node is a comment
--- @param node TSNode
--- @return boolean
function M.is_comment(node)
    local node_type = node:type()
    return node_type == "comment"
        or node_type == "line_comment"
        or node_type == "block_comment"
        or node_type:match "comment$" ~= nil
end

return M
