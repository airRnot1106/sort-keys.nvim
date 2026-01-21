---Base adapter with shared functionality
---@class BaseAdapter: SortKeysAdapter
local M = {}

---Create a new adapter by extending base
---@param config table
---@return SortKeysAdapter
function M.create(config)
  local adapter = {}

  -- Required fields
  adapter.name = config.name or error("Adapter name is required")
  adapter.filetypes = config.filetypes or error("Adapter filetypes are required")

  -- Required methods
  adapter.get_sortable_node_types = config.get_sortable_node_types
    or error("get_sortable_node_types is required")
  adapter.get_entry_node_type = config.get_entry_node_type or error("get_entry_node_type is required")
  adapter.extract_key = config.extract_key or error("extract_key is required")

  -- Optional methods with defaults
  adapter.is_sortable_entry = config.is_sortable_entry or function(node)
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

  adapter.get_separator = config.get_separator or function()
    return ","
  end

  adapter.get_nested_objects = config.get_nested_objects or function(entry_node, source)
    local results = {}
    local sortable_types = adapter.get_sortable_node_types()
    local type_set = {}
    for _, t in ipairs(sortable_types) do
      type_set[t] = true
    end

    local function traverse(node)
      if type_set[node:type()] then
        table.insert(results, node)
      end
      for child in node:iter_children() do
        traverse(child)
      end
    end

    for child in entry_node:iter_children() do
      traverse(child)
    end

    return results
  end

  adapter.get_comment_node_types = config.get_comment_node_types or function()
    return { "comment" }
  end

  return adapter
end

return M
