local toml_loader = require("sort-keys.core.toml_loader")
local json_builder = require("sort-keys.handlers.declarative.json_builder")

local M = {}

local DECLARATIVE_BUILDERS = {
  json = json_builder,
  jsonc = json_builder,
}

local TOML_PATH_FMT = "lua/sort-keys/handlers/declarative/%s.toml"
local QUERY_PATH_FMT = "queries/%s/%s"

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then
    error(string.format("registry: cannot open %s: %s", path, err or "unknown error"))
  end
  local text = f:read("*a")
  f:close()
  return text
end

local function locate_runtime(rel_path)
  local found = vim.api.nvim_get_runtime_file(rel_path, false)
  return found[1]
end

local function build_capabilities(toml)
  return {
    can_sort_object = toml.can_sort_object,
    can_sort_array = toml.can_sort_array,
    can_deep = toml.can_deep,
    comment_aware = toml.comment_aware,
    key_quoting = toml.key_quoting,
    requires_treesitter = true,
  }
end

local function load_declarative(filetype, builder)
  local toml_path = locate_runtime(TOML_PATH_FMT:format(filetype))
  if not toml_path then
    return nil
  end
  local toml = toml_loader.load(toml_path)
  if not toml.query_file then
    error(string.format("registry: %s is missing query_file", toml_path))
  end

  local query_path = locate_runtime(QUERY_PATH_FMT:format(filetype, toml.query_file))
  if not query_path then
    return nil
  end
  local query_text = read_file(query_path)

  return {
    capabilities = build_capabilities(toml),
    outline = function(bufnr, target)
      return builder.build(bufnr, target, {
        filetype = filetype,
        query_text = query_text,
        toml = toml,
      })
    end,
  }
end

---@param filetype string
---@return table|nil
function M.get(filetype)
  local builder = DECLARATIVE_BUILDERS[filetype]
  if not builder then
    return nil
  end
  return load_declarative(filetype, builder)
end

return M
