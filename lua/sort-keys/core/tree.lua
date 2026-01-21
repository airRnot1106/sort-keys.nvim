---Treesitter utilities for sort-keys
local M = {}

---Get Treesitter parser for buffer
---@param bufnr integer
---@return vim.treesitter.LanguageTree|nil
function M.get_parser(bufnr)
    local filetype = vim.bo[bufnr].filetype
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, filetype)
    if not ok then
        return nil
    end
    return parser
end

---Get the root node of the syntax tree
---@param bufnr integer
---@return TSNode|nil
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

---Find the smallest sortable node containing the given position
---@param root TSNode
---@param row integer 0-indexed row
---@param col integer 0-indexed column
---@param sortable_types string[]
---@return TSNode|nil
function M.find_sortable_node_at_position(root, row, col, sortable_types)
    local node = root:named_descendant_for_range(row, col, row, col)
    if not node then
        return nil
    end

    -- Walk up the tree to find a sortable node
    while node do
        local node_type = node:type()
        for _, sortable_type in ipairs(sortable_types) do
            if node_type == sortable_type then
                return node
            end
        end
        node = node:parent()
    end

    return nil
end

---Check if node_a is an ancestor of node_b
---@param node_a TSNode
---@param node_b TSNode
---@return boolean
local function is_ancestor_of(node_a, node_b)
    local parent = node_b:parent()
    while parent do
        if parent:id() == node_a:id() then
            return true
        end
        parent = parent:parent()
    end
    return false
end

---Find all sortable nodes within a range (innermost only)
---@param root TSNode
---@param start_row integer 0-indexed start row
---@param end_row integer 0-indexed end row
---@param sortable_types string[]
---@return TSNode[]
function M.find_sortable_nodes_in_range(root, start_row, end_row, sortable_types)
    local candidates = {}
    local type_set = {}
    for _, t in ipairs(sortable_types) do
        type_set[t] = true
    end

    ---@param node TSNode
    local function traverse(node)
        local node_start_row, _, node_end_row, _ = node:range()

        -- Skip nodes completely outside the range
        if node_end_row < start_row or node_start_row > end_row then
            return
        end

        -- Check if this node is sortable
        if type_set[node:type()] then
            table.insert(candidates, node)
        end

        -- Traverse children
        for child in node:iter_children() do
            traverse(child)
        end
    end

    traverse(root)

    -- Filter out nodes that are ancestors of other nodes in the list
    -- Keep only the innermost (most nested) nodes
    local results = {}
    for _, node in ipairs(candidates) do
        local is_ancestor = false
        for _, other in ipairs(candidates) do
            if node:id() ~= other:id() and is_ancestor_of(node, other) then
                is_ancestor = true
                break
            end
        end
        if not is_ancestor then
            table.insert(results, node)
        end
    end

    return results
end

---Collect all sortable nodes within a parent node (for deep sort)
---@param parent_node TSNode
---@param sortable_types string[]
---@return TSNode[]
function M.collect_nested_sortable_nodes(parent_node, sortable_types)
    local results = {}
    local type_set = {}
    for _, t in ipairs(sortable_types) do
        type_set[t] = true
    end

    ---@param node TSNode
    local function traverse(node)
        if type_set[node:type()] then
            table.insert(results, node)
        end
        for child in node:iter_children() do
            traverse(child)
        end
    end

    -- Start from children, not the parent itself
    for child in parent_node:iter_children() do
        traverse(child)
    end

    return results
end

---Get the depth of a node in the tree
---@param node TSNode
---@return integer
function M.get_node_depth(node)
    local depth = 0
    local current = node:parent()
    while current do
        depth = depth + 1
        current = current:parent()
    end
    return depth
end

---Get node text
---@param node TSNode
---@param bufnr integer
---@return string
function M.get_node_text(node, bufnr)
    return vim.treesitter.get_node_text(node, bufnr)
end

return M
