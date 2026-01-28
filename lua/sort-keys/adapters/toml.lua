--- TOML adapter for sort-keys.nvim
local base = require "sort-keys.adapters.base"
local ts_utils = require "sort-keys.utils.treesitter"
local text_utils = require "sort-keys.utils.text"

local adapter = base.create {
    -- Filetypes this adapter handles
    filetypes = { "toml" },

    -- Container types
    container_types = {
        "table",
        "table_array_element",
        "inline_table",
        "array",
    },

    -- No element wrappers
    element_wrappers = {},

    -- Element types for each container
    element_types = {
        table = "pair",
        table_array_element = "pair",
        inline_table = "pair",
        array = nil, -- Arrays use direct children
    },

    -- Separators
    separators = {
        table = "", -- Newline separated
        table_array_element = "", -- Newline separated
        inline_table = ",",
        array = ",",
    },

    -- Brackets
    brackets = {
        inline_table = { "{", "}" },
        array = { "[", "]" },
        -- table and table_array_element have no brackets (header only)
    },

    -- No excluded types
    exclude_types = {},

    -- Key extraction
    get_key_from_element = function(element, bufnr)
        local elem_type = element:type()

        if elem_type == "pair" then
            -- TOML tree-sitter doesn't use fields, so we need to get the first named child
            -- which should be the key (bare_key, quoted_key, or dotted_key)
            for child in element:iter_children() do
                if child:named() then
                    local child_type = child:type()
                    if child_type == "bare_key" or child_type == "quoted_key" or child_type == "dotted_key" then
                        local text = ts_utils.get_node_text(child, bufnr)
                        -- Remove quotes from quoted keys
                        return text:gsub('^"', ""):gsub('"$', ""):gsub("^'", ""):gsub("'$", "")
                    end
                end
            end
        end

        -- For array elements, use the text itself as the key
        return ts_utils.get_node_text(element, bufnr)
    end,
}

-- Customize format_output to preserve headers for table and table_array_element
local original_format_output = adapter.format_output

function adapter.format_output(elements, container, bufnr, had_trailing_separator)
    local lines = original_format_output(elements, container, bufnr, had_trailing_separator)

    -- For table / table_array_element, prepend the header line
    if container.type == "table" or container.type == "table_array_element" then
        local header_line = text_utils.get_lines(bufnr, container.start_row, container.start_row)[1]
        table.insert(lines, 1, header_line)
    end

    return lines
end

return adapter
