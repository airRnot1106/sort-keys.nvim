---Adapter registry for sort-keys
---@class AdapterRegistry
---@field adapters table<string, SortKeysAdapter>
local M = {
  adapters = {},
}

---Built-in adapter module paths indexed by filetype
local builtin_adapters = {
  json = "sort-keys.adapters.json",
  jsonc = "sort-keys.adapters.json",
  javascript = "sort-keys.adapters.javascript",
  javascriptreact = "sort-keys.adapters.javascript",
  typescript = "sort-keys.adapters.typescript",
  typescriptreact = "sort-keys.adapters.typescript",
  lua = "sort-keys.adapters.lua",
}

---Register a new adapter
---@param adapter SortKeysAdapter
function M.register(adapter)
  for _, ft in ipairs(adapter.filetypes) do
    M.adapters[ft] = adapter
  end
end

---Get adapter for a filetype
---@param filetype string
---@return SortKeysAdapter|nil
function M.get(filetype)
  -- Check if already registered
  if M.adapters[filetype] then
    return M.adapters[filetype]
  end

  -- Try to load built-in adapter
  local module_path = builtin_adapters[filetype]
  if module_path then
    local ok, adapter = pcall(require, module_path)
    if ok and adapter then
      M.register(adapter)
      return M.adapters[filetype]
    end
  end

  return nil
end

---Check if filetype is supported
---@param filetype string
---@return boolean
function M.is_supported(filetype)
  return M.adapters[filetype] ~= nil or builtin_adapters[filetype] ~= nil
end

---Get list of supported filetypes
---@return string[]
function M.get_supported_filetypes()
  local filetypes = {}
  local seen = {}

  -- Add registered adapters
  for ft, _ in pairs(M.adapters) do
    if not seen[ft] then
      table.insert(filetypes, ft)
      seen[ft] = true
    end
  end

  -- Add built-in adapters
  for ft, _ in pairs(builtin_adapters) do
    if not seen[ft] then
      table.insert(filetypes, ft)
      seen[ft] = true
    end
  end

  table.sort(filetypes)
  return filetypes
end

return M
