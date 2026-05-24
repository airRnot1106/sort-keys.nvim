local toml_loader = require("sort-keys.core.toml_loader")
local json_builder = require("sort-keys.handlers.json_builder")
local yaml_builder = require("sort-keys.handlers.yaml_builder")
local javascript_builder = require("sort-keys.handlers.javascript_builder")
local lua_builder = require("sort-keys.handlers.lua_builder")
local toml_builder = require("sort-keys.handlers.toml_builder")
local nix_builder = require("sort-keys.handlers.nix_builder")

local M = {}

-- Each builder self-declares the filetypes it serves and the canonical
-- config name each filetype maps to (see `builder.filetypes`). The
-- registry only enumerates known builders and aggregates those
-- declarations into a single lookup map — it never hardcodes which
-- filetypes belong to which language.
local BUILDERS = {
  json_builder,
  yaml_builder,
  javascript_builder,
  lua_builder,
  toml_builder,
  nix_builder,
}

local function build_filetype_table(builders)
  local out = {}
  for _, builder in ipairs(builders) do
    for filetype, config_name in pairs(builder.filetypes or {}) do
      out[filetype] = { builder = builder, config_name = config_name }
    end
  end
  return out
end

local FILETYPE_TABLE = build_filetype_table(BUILDERS)

local TOML_PATH_FMT = "lua/sort-keys/handlers/%s.toml"
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

local function build_capabilities(options)
  return {
    can_sort_object = options.can_sort_object,
    can_sort_array = options.can_sort_array,
    can_deep = options.can_deep,
    comment_aware = options.comment_aware,
    key_quoting = options.key_quoting,
    requires_treesitter = true,
  }
end

local function load_handler(entry)
  local builder = entry.builder
  local config_name = entry.config_name
  local options_path = locate_runtime(TOML_PATH_FMT:format(config_name))
  if not options_path then
    return nil
  end
  local options = toml_loader.load(options_path)
  if not options.query_file then
    error(string.format("registry: %s is missing query_file", options_path))
  end

  local query_path = locate_runtime(QUERY_PATH_FMT:format(config_name, options.query_file))
  if not query_path then
    return nil
  end
  local query_text = read_file(query_path)

  return {
    capabilities = build_capabilities(options),
    outline = function(bufnr, target)
      return builder.build(bufnr, target, {
        filetype = config_name,
        query_text = query_text,
        options = options,
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
  return load_handler(entry)
end

return M
