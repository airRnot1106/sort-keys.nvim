---JavaScript adapter for sort-keys
local base = require "sort-keys.adapters.base"
local tree_utils = require "sort-keys.core.tree"

local M = base.create {
    name = "javascript",
    filetypes = { "javascript", "javascriptreact" },

    get_sortable_node_types = function()
        return { "object" }
    end,

    get_entry_node_type = function()
        return { "pair", "method_definition", "shorthand_property_identifier" }
    end,

    extract_key = function(entry_node, source)
        local node_type = entry_node:type()

        if node_type == "pair" then
            -- pair -> key field (property_identifier, string, computed_property_name, number)
            for child in entry_node:iter_children() do
                local child_type = child:type()
                if
                    child_type == "property_identifier"
                    or child_type == "string"
                    or child_type == "number"
                    or child_type == "computed_property_name"
                then
                    local text = tree_utils.get_node_text(child, source)
                    -- Remove quotes if string key
                    if child_type == "string" then
                        -- Handle both single and double quotes
                        if text:match "^[\"']" then
                            return text:sub(2, -2)
                        end
                    end
                    return text
                end
            end
        elseif node_type == "method_definition" then
            -- method_definition -> name field
            for child in entry_node:iter_children() do
                if child:type() == "property_identifier" then
                    return tree_utils.get_node_text(child, source)
                end
            end
        elseif node_type == "shorthand_property_identifier" then
            return tree_utils.get_node_text(entry_node, source)
        end

        return nil
    end,

    is_sortable_entry = function(node)
        local node_type = node:type()
        -- Exclude spread elements, comments
        return node_type == "pair" or node_type == "method_definition" or node_type == "shorthand_property_identifier"
    end,

    get_comment_node_types = function()
        return { "comment" }
    end,
}

return M
