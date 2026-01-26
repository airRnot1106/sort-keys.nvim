--- TypeScript adapter for sort-keys.nvim
local base = require "sort-keys.adapters.base"
local ts_utils = require "sort-keys.utils.treesitter"

return base.create {
    -- Filetypes this adapter handles
    filetypes = { "typescript", "typescriptreact" },

    -- Container types
    container_types = { "object", "array", "object_type", "formal_parameters", "object_pattern" },

    -- No element wrappers
    element_wrappers = {},

    -- Element types
    element_types = {
        object = nil, -- Objects can have pair, shorthand_property_identifier, spread_element, etc.
        array = nil, -- Arrays use direct children
        object_type = nil, -- TypeScript object types can have property_signature, index_signature, etc.
        formal_parameters = nil, -- Function parameters
        object_pattern = nil, -- Destructuring patterns
    },

    -- Separators
    separators = {
        object = ",",
        array = ",",
        object_type = ";",
        formal_parameters = ",",
        object_pattern = ",",
    },

    -- Excluded types (spread elements and rest patterns stay in place)
    exclude_types = { "spread_element", "rest_pattern" },

    -- Key extraction
    get_key_from_element = function(element, bufnr)
        local elem_type = element:type()

        if elem_type == "pair" then
            -- { key: value } or { "key": value }
            local key_node = element:field("key")[1]
            if key_node then
                local text = ts_utils.get_node_text(key_node, bufnr)
                -- Remove quotes if present
                return (text:gsub("^[\"']", ""):gsub("[\"']$", ""))
            end
        elseif elem_type == "shorthand_property_identifier" or elem_type == "shorthand_property_identifier_pattern" then
            -- { key } shorthand or destructuring pattern
            return ts_utils.get_node_text(element, bufnr)
        elseif elem_type == "method_definition" then
            -- { method() {} }
            local name_node = element:field("name")[1]
            if name_node then
                return ts_utils.get_node_text(name_node, bufnr)
            end
        elseif elem_type == "property_signature" then
            -- TypeScript: { name: string; }
            local name_node = element:field("name")[1]
            if name_node then
                local text = ts_utils.get_node_text(name_node, bufnr)
                return (text:gsub("^[\"']", ""):gsub("[\"']$", ""))
            end
        elseif elem_type == "required_parameter" or elem_type == "optional_parameter" then
            -- Function parameters: (name: string, age?: number)
            local pattern_node = element:field("pattern")[1]
            if pattern_node then
                return ts_utils.get_node_text(pattern_node, bufnr)
            end
        elseif elem_type == "spread_element" or elem_type == "rest_pattern" then
            -- { ...obj } or (...args) - keep original position, return nil for key
            return nil
        end

        -- For array elements or other types, use the text itself
        return ts_utils.get_node_text(element, bufnr)
    end,
}
