--- JavaScript/TypeScript adapter for sort-keys.nvim
local base = require "sort-keys.adapters.base"

return base.create {
    -- Filetypes this adapter handles
    filetypes = { "javascript", "typescript", "jsx", "tsx", "javascriptreact", "typescriptreact" },

    -- Container types
    container_types = { "object", "array" },

    -- No element wrappers
    element_wrappers = {},

    -- Element types
    element_types = {
        object = nil, -- Objects can have pair, shorthand_property_identifier, spread_element, etc.
        array = nil, -- Arrays use direct children
    },

    -- Separators
    separators = {
        object = ",",
        array = ",",
    },

    -- Excluded types (spread elements stay in place)
    exclude_types = { "spread_element" },

    -- Key extraction
    get_key_from_element = function(element, bufnr)
        local elem_type = element:type()

        if elem_type == "pair" then
            -- { key: value } or { "key": value }
            local key_node = element:field("key")[1]
            if key_node then
                local text = vim.treesitter.get_node_text(key_node, bufnr)
                -- Remove quotes if present
                return (text:gsub("^[\"']", ""):gsub("[\"']$", ""))
            end
        elseif elem_type == "shorthand_property_identifier" then
            -- { key } shorthand
            return vim.treesitter.get_node_text(element, bufnr)
        elseif elem_type == "method_definition" then
            -- { method() {} }
            local name_node = element:field("name")[1]
            if name_node then
                return vim.treesitter.get_node_text(name_node, bufnr)
            end
        elseif elem_type == "spread_element" then
            -- { ...obj } - keep original position, return nil for key
            return nil
        end

        -- For array elements or other types, use the text itself
        return vim.treesitter.get_node_text(element, bufnr)
    end,
}
