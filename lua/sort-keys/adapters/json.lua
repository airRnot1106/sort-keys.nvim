---JSON adapter for sort-keys
local base = require "sort-keys.adapters.base"
local tree_utils = require "sort-keys.core.tree"

local M = base.create {
    name = "json",
    filetypes = { "json", "jsonc" },

    get_sortable_node_types = function()
        return { "object" }
    end,

    get_entry_node_type = function()
        return "pair"
    end,

    extract_key = function(pair_node, source)
        -- JSON pair structure: pair -> [key: string, value: _value]
        for child in pair_node:iter_children() do
            if child:type() == "string" then
                local text = tree_utils.get_node_text(child, source)
                -- Remove quotes: "key" -> key
                return text:sub(2, -2)
            end
        end
        return nil
    end,

    is_sortable_entry = function(node)
        return node:type() == "pair"
    end,

    get_comment_node_types = function()
        -- jsonc supports comments
        return { "comment" }
    end,
}

return M
