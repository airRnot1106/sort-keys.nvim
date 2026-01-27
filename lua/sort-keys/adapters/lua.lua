--- Lua adapter for sort-keys.nvim
local base = require "sort-keys.adapters.base"
local ts_utils = require "sort-keys.utils.treesitter"

return base.create {
    -- Filetypes this adapter handles
    filetypes = { "lua" },

    -- Container types
    container_types = { "table_constructor" },

    -- No element wrappers
    element_wrappers = {},

    -- Element types
    element_types = {
        table_constructor = "field",
    },

    -- Separators
    separators = {
        table_constructor = ",",
    },

    -- Brackets
    brackets = {
        table_constructor = { "{", "}" },
    },

    -- No excluded types
    exclude_types = {},

    -- Key extraction
    get_key_from_element = function(element, bufnr)
        if element:type() == "field" then
            -- Check if this is a vararg expression (...) - should stay in place
            local value_node = element:field("value")[1]
            if value_node and value_node:type() == "vararg_expression" then
                return nil -- Exclude from sorting
            end

            -- Lua fields can have different forms:
            -- { key = value }  -- named field
            -- { ["key"] = value }  -- bracket field
            -- { value }  -- array-like field

            local name_node = element:field("name")[1]
            if name_node then
                return ts_utils.get_node_text(name_node, bufnr)
            end

            -- Check for bracket notation [key]
            for child in element:iter_children() do
                if child:type() == "[" then
                    local next = child:next_sibling()
                    if next and next:named() then
                        local text = ts_utils.get_node_text(next, bufnr)
                        -- Remove quotes if present
                        return (text:gsub("^[\"']", ""):gsub("[\"']$", ""))
                    end
                end
            end
        end
        -- For array-like entries, use the text itself
        return ts_utils.get_node_text(element, bufnr)
    end,
}
