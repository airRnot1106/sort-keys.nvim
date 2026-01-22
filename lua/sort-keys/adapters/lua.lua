---Lua adapter for sort-keys
local base = require "sort-keys.adapters.base"
local tree_utils = require "sort-keys.core.tree"

local M = base.create {
    name = "lua",
    filetypes = { "lua" },

    get_sortable_node_types = function()
        return { "table_constructor" }
    end,

    get_entry_node_type = function()
        return "field"
    end,

    extract_key = function(field_node, source)
        -- Lua field can be:
        -- 1. name = value (identifier key)
        -- 2. ["key"] = value (bracket string key)
        -- 3. [expr] = value (bracket expression key)
        -- 4. value (no key, array-like) - should not be sorted

        for child in field_node:iter_children() do
            local child_type = child:type()

            -- Check for identifier key (name = value)
            if child_type == "identifier" then
                return tree_utils.get_node_text(child, source)
            end

            -- Check for bracket notation [key]
            if child_type == "string" then
                local text = tree_utils.get_node_text(child, source)
                -- Remove brackets and quotes: ["key"] or ['key'] -> key
                text = text:gsub("^%[?[\"']?", ""):gsub("[\"']?%]?$", "")
                return text
            end
        end

        -- No key found (array-style entry)
        return nil
    end,

    is_sortable_entry = function(field_node)
        if field_node:type() ~= "field" then
            return false
        end

        -- Only sort fields that have explicit keys
        -- Array-style fields (without =) should not be sorted
        local has_key = false
        for child in field_node:iter_children() do
            local child_type = child:type()
            if child_type == "identifier" or child_type == "string" then
                has_key = true
                break
            end
        end

        return has_key
    end,

    get_comment_node_types = function()
        return { "comment" }
    end,
}

return M
