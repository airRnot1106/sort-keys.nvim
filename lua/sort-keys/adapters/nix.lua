---Nix adapter for sort-keys
local base = require "sort-keys.adapters.base"
local tree_utils = require "sort-keys.core.tree"

-- Node types that use semicolon separator
local semicolon_types = {
    attrset_expression = true,
    rec_attrset_expression = true,
    let_attrset_expression = true,
}

-- Node types that use no separator (space/newline separated)
local no_separator_types = {
    list_expression = true,
}

local M = base.create {
    name = "nix",
    filetypes = { "nix" },

    get_sortable_node_types = function()
        return {
            "attrset_expression",
            "rec_attrset_expression",
            "let_attrset_expression",
            "formals",
            "list_expression",
        }
    end,

    get_entry_node_type = function()
        return { "binding", "formal", "variable_expression" }
    end,

    get_entry_container_types = function()
        return { "binding_set" }
    end,

    extract_key = function(entry_node, source)
        local node_type = entry_node:type()

        if node_type == "binding" then
            -- binding -> attrpath -> (identifier | string_expression | interpolation)
            for child in entry_node:iter_children() do
                if child:type() == "attrpath" then
                    -- Get first attr in attrpath (for simple keys like `foo = ...`)
                    for attr in child:iter_children() do
                        local attr_type = attr:type()
                        if attr_type == "identifier" then
                            return tree_utils.get_node_text(attr, source)
                        elseif attr_type == "string_expression" then
                            local text = tree_utils.get_node_text(attr, source)
                            -- Remove quotes: "key" -> key
                            return text:gsub('^"', ""):gsub('"$', "")
                        end
                    end
                end
            end
        elseif node_type == "formal" then
            -- formal -> identifier (the parameter name)
            for child in entry_node:iter_children() do
                if child:type() == "identifier" then
                    return tree_utils.get_node_text(child, source)
                end
            end
        elseif node_type == "variable_expression" then
            -- variable_expression -> identifier (for list elements)
            for child in entry_node:iter_children() do
                if child:type() == "identifier" then
                    return tree_utils.get_node_text(child, source)
                end
            end
            -- Fallback: use the whole text
            return tree_utils.get_node_text(entry_node, source)
        end

        return nil
    end,

    is_sortable_entry = function(node)
        local node_type = node:type()
        -- ellipsis (...) should not be sorted
        if node_type == "ellipsis" then
            return false
        end
        return node_type == "binding" or node_type == "formal" or node_type == "variable_expression"
    end,

    get_separator = function(object_node)
        if object_node then
            local node_type = object_node:type()
            if semicolon_types[node_type] then
                return ";"
            end
            if no_separator_types[node_type] then
                return ""
            end
        end
        -- formals use comma
        return ","
    end,

    get_comment_node_types = function()
        return { "comment" }
    end,
}

return M
