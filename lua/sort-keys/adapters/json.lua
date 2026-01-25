--- JSON adapter for sort-keys.nvim
local base = require "sort-keys.adapters.base"

return base.create {
    -- Filetypes this adapter handles
    filetypes = { "json", "jsonc", "json5" },

    -- Container types
    container_types = { "object", "array" },

    -- No element wrappers
    element_wrappers = {},

    -- Element types for each container
    element_types = {
        object = "pair",
        array = nil, -- Arrays use direct children
    },

    -- Separators
    separators = {
        object = ",",
        array = ",",
    },

    -- No excluded types
    exclude_types = {},

    -- Key extraction
    get_key_from_element = function(element, bufnr)
        if element:type() == "pair" then
            local key_node = element:field("key")[1]
            if key_node then
                local text = vim.treesitter.get_node_text(key_node, bufnr)
                -- Remove quotes from string keys
                return text:gsub('^"', ""):gsub('"$', "")
            end
        end
        -- For array elements, use the text itself as the key
        return vim.treesitter.get_node_text(element, bufnr)
    end,
}
