---Base adapter with shared functionality
---@class BaseAdapter: SortKeysAdapter
local M = {}

---Create a new adapter by extending base
---@param config table
---@return SortKeysAdapter
function M.create(config)
    local adapter = {}

    -- Required fields
    adapter.name = config.name or error "Adapter name is required"
    adapter.filetypes = config.filetypes or error "Adapter filetypes are required"

    -- Required methods
    adapter.get_sortable_node_types = config.get_sortable_node_types or error "get_sortable_node_types is required"
    adapter.get_entry_node_type = config.get_entry_node_type or error "get_entry_node_type is required"
    adapter.extract_key = config.extract_key or error "extract_key is required"

    -- Optional methods with defaults
    adapter.is_sortable_entry = config.is_sortable_entry
        or function(node)
            local entry_types = adapter.get_entry_node_type()
            if type(entry_types) == "string" then
                return node:type() == entry_types
            else
                for _, t in ipairs(entry_types) do
                    if node:type() == t then
                        return true
                    end
                end
                return false
            end
        end

    -- get_separator can optionally receive the object_node to determine separator based on context
    adapter.get_separator = config.get_separator or function(_object_node)
        return ","
    end

    adapter.get_comment_node_types = config.get_comment_node_types or function()
        return { "comment" }
    end

    -- Optional: intermediate container types (e.g., binding_set in Nix)
    -- If provided, entries are searched inside these containers instead of direct children
    adapter.get_entry_container_types = config.get_entry_container_types or nil

    return adapter
end

return M
