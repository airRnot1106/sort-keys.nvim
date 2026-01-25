---@meta

---Sorting options
---@class SortKeysOptions
---@field reverse boolean Sort in reverse order
---@field deep boolean Recursively sort nested objects
---@field case_sensitive boolean Case-sensitive sorting (default: true)
---@field natural_sort boolean Natural number sorting (default: false)

---Configuration for the plugin
---@class SortKeysConfig
---@field default_options SortKeysOptions Default sorting options
---@field custom_adapters SortKeysAdapter[] Custom adapters to register

---Partial Configuration for the plugin
---@class SortKeysPartialConfig
---@field default_options? SortKeysOptions Default sorting options
---@field custom_adapters? SortKeysAdapter[] Custom adapters to register

---Entry extracted from an object node
---@class SortKeysEntry
---@field node TSNode The Treesitter node
---@field key string The extracted key for sorting
---@field text string The original text of the entry
---@field start_row integer 0-indexed start row
---@field start_col integer 0-indexed start column
---@field end_row integer 0-indexed end row
---@field end_col integer 0-indexed end column
---@field leading_comments string[] Comments before this entry

---Adapter interface for language-specific implementations
---@class SortKeysAdapter
---@field name string Adapter name (e.g., "json", "javascript")
---@field filetypes string[] Supported filetypes
local SortKeysAdapter = {}

---Get node types that represent sortable objects
---@return string[]
function SortKeysAdapter.get_sortable_node_types() end

---Get the node type for key-value entries
---@return string|string[]
function SortKeysAdapter.get_entry_node_type() end

---Extract the key string from an entry node
---@param entry_node TSNode
---@param source integer Buffer number
---@return string|nil
function SortKeysAdapter.extract_key(entry_node, source) end

---Check if a child node is a sortable entry
---@param node TSNode
---@return boolean
function SortKeysAdapter.is_sortable_entry(node) end

---Get the separator between entries
---@param object_node? TSNode The parent object node for context-aware separator selection
---@return string
function SortKeysAdapter.get_separator(object_node) end

---Get comment node types for this language
---@return string[]
function SortKeysAdapter.get_comment_node_types() end

---Get intermediate container types (optional)
---Some languages have intermediate container nodes between the object and entries
---(e.g., binding_set in Nix between attrset_expression and binding)
---@return string[]|nil
function SortKeysAdapter.get_entry_container_types() end

return {}
