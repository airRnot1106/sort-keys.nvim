--- Nix adapter for sort-keys.nvim
local base = require "sort-keys.adapters.base"
local ts_utils = require "sort-keys.utils.treesitter"

return base.create {
    -- Filetypes this adapter handles
    filetypes = { "nix" },

    -- Container types
    container_types = { "attrset_expression", "list_expression", "formals" },

    -- Element wrappers (intermediate nodes)
    element_wrappers = {
        attrset_expression = "binding_set",
    },

    -- Element types
    element_types = {
        attrset_expression = "binding",
        list_expression = nil, -- Lists use direct children
        formals = "formal",
    },

    -- Separators
    separators = {
        attrset_expression = ";",
        list_expression = "", -- Whitespace separated
        formals = ",",
    },

    -- Excluded types (ellipses in function args)
    exclude_types = { "ellipses" },

    -- Key extraction
    get_key_from_element = function(element, bufnr)
        local elem_type = element:type()

        if elem_type == "binding" then
            -- { name = value; }
            local attrpath = element:field("attrpath")[1]
            if attrpath then
                -- attrpath can be nested like a.b.c
                -- Get the first identifier
                for child in attrpath:iter_children() do
                    if child:type() == "identifier" or child:type() == "string_expression" then
                        local text = ts_utils.get_node_text(child, bufnr)
                        -- Remove quotes if present
                        return text:gsub('^"', ""):gsub('"$', "")
                    end
                end
                return ts_utils.get_node_text(attrpath, bufnr)
            end
        elseif elem_type == "formal" then
            -- Function argument: { name ? default }
            local name_node = element:field("name")[1]
            if name_node then
                return ts_utils.get_node_text(name_node, bufnr)
            end
        elseif elem_type == "ellipses" then
            -- ... in function args - keep in place
            return nil
        end

        -- For list elements, use the text itself
        return ts_utils.get_node_text(element, bufnr)
    end,
}
