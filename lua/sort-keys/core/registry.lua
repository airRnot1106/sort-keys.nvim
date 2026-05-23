local toml_loader = require("sort-keys.core.toml_loader")
local json_builder = require("sort-keys.handlers.declarative.json_builder")
local yaml_builder = require("sort-keys.handlers.declarative.yaml_builder")
local javascript_builder = require("sort-keys.handlers.declarative.javascript_builder")

local M = {}

-- Each declarative builder self-declares the filetypes it serves and the
-- canonical config name each filetype maps to (see `builder.filetypes`).
-- The registry only enumerates known builders and aggregates those
-- declarations into a single lookup map — it never hardcodes which
-- filetypes belong to which language.
local DECLARATIVE_BUILDERS = { json_builder, yaml_builder, javascript_builder }

local function build_filetype_table(builders)
  local out = {}
  for _, builder in ipairs(builders) do
    for filetype, config_name in pairs(builder.filetypes or {}) do
      out[filetype] = { builder = builder, config_name = config_name }
    end
  end
  return out
end

local FILETYPE_TABLE = build_filetype_table(DECLARATIVE_BUILDERS)

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

local function load_declarative(entry)
  local builder = entry.builder
  local config_name = entry.config_name
  local toml_path = locate_runtime(TOML_PATH_FMT:format(config_name))
  if not toml_path then
    return nil
  end
  local toml = toml_loader.load(toml_path)
  if not toml.query_file then
    error(string.format("registry: %s is missing query_file", toml_path))
  end

  local query_path = locate_runtime(QUERY_PATH_FMT:format(config_name, toml.query_file))
  if not query_path then
    return nil
  end
  local query_text = read_file(query_path)

  return {
    capabilities = build_capabilities(toml),
    outline = function(bufnr, target)
      return builder.build(bufnr, target, {
        filetype = config_name,
        query_text = query_text,
        toml = toml,
      })
    end,
  }
end

---@param filetype string
---@return table|nil
function M.get(filetype)
  local entry = FILETYPE_TABLE[filetype]
  if not entry then
    return nil
  end
  return load_declarative(entry)
end

return M
