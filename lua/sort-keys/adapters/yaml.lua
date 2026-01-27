--- YAML adapter for sort-keys.nvim
local base = require "sort-keys.adapters.base"
local ts_utils = require "sort-keys.utils.treesitter"

return base.create {
    -- Filetypes this adapter handles
    filetypes = { "yaml" },

    -- Container types
    container_types = {
        "flow_mapping",
        "block_mapping",
        "flow_sequence",
        "block_sequence",
    },

    -- No element wrappers
    element_wrappers = {},

    -- Element types for each container
    element_types = {
        flow_mapping = "flow_pair",
        block_mapping = "block_mapping_pair",
        flow_sequence = nil, -- Uses direct children
        block_sequence = "block_sequence_item",
    },

    -- Separators
    separators = {
        flow_mapping = ",",
        block_mapping = "", -- Newline separated
        flow_sequence = ",",
        block_sequence = "", -- Newline separated
    },

    -- Brackets (nil for block-style containers)
    brackets = {
        flow_mapping = { "{", "}" },
        flow_sequence = { "[", "]" },
        -- block_mapping and block_sequence have no brackets
    },

    -- Excluded types (anchors, aliases)
    exclude_types = { "anchor", "alias" },

    -- Key extraction
    get_key_from_element = function(element, bufnr)
        local elem_type = element:type()

        if elem_type == "flow_pair" or elem_type == "block_mapping_pair" then
            local key_node = element:field("key")[1]
            if key_node then
                -- Key can be flow_node or block_node containing scalar
                local text = ts_utils.get_node_text(key_node, bufnr)
                -- Remove quotes if present
                return text:gsub('^"', ""):gsub('"$', ""):gsub("^'", ""):gsub("'$", "")
            end
        elseif elem_type == "block_sequence_item" then
            -- For block sequence items, get the value node
            local value_node = element:field("value")[1]
            if value_node then
                return ts_utils.get_node_text(value_node, bufnr)
            end
        end

        -- For flow sequence elements, use the text itself
        return ts_utils.get_node_text(element, bufnr)
    end,
}
