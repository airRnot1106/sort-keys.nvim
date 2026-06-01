local javascript_builder = require("sort-keys.languages.javascript.builder")
local json_builder = require("sort-keys.languages.json.builder")
local kdl_builder = require("sort-keys.languages.kdl.builder")
local lua_builder = require("sort-keys.languages.lua.builder")
local nix_builder = require("sort-keys.languages.nix.builder")
local pkl_builder = require("sort-keys.languages.pkl.builder")
local python_builder = require("sort-keys.languages.python.builder")
local toml_builder = require("sort-keys.languages.toml.builder")
local toml_loader = require("sort-keys.core.toml_loader")
local yaml_builder = require("sort-keys.languages.yaml.builder")

local M = {}

-- Each built-in builder self-declares the filetypes it serves and the
-- canonical config name each filetype maps to (see `builder.filetypes`).
local BUILT_IN_BUILDERS = {
  javascript_builder,
  json_builder,
  kdl_builder,
  lua_builder,
  nix_builder,
  pkl_builder,
  python_builder,
  toml_builder,
  yaml_builder,
}

-- Built-ins indexed by config_name. Used by partial-override to find a base
-- spec when a user spec's key matches a built-in.
local BUILT_IN_BY_CONFIG_NAME = {}
for _, builder in ipairs(BUILT_IN_BUILDERS) do
  for _, config_name in pairs(builder.filetypes or {}) do
    BUILT_IN_BY_CONFIG_NAME[config_name] = builder
  end
end

local TOML_PATH_FMT = "lua/sort-keys/languages/%s/config.toml"
local QUERY_PATH_FMT = "lua/sort-keys/languages/%s/%s"

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

-- Loads the raw spec table (filetypes / builder / options / query_text) for
-- a built-in handler off disk. Used directly when serving a built-in and as
-- the base for partial-override merging when a user spec targets the same
-- config_name.
local function load_built_in_spec(builder, config_name)
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

  -- builder.filetypes is a dict { filetype = config_name }; collapse to the
  -- list of filetypes that map to this specific config_name.
  local filetypes = {}
  for filetype, cn in pairs(builder.filetypes or {}) do
    if cn == config_name then
      filetypes[#filetypes + 1] = filetype
    end
  end

  return {
    filetypes = filetypes,
    builder = builder,
    options = options,
    query_text = query_text,
  }
end

-- Turn a resolved spec (whether built-in, user-only, or merged) into the
-- `{ capabilities, outline }` handler shape that M.get returns.
local function spec_to_handler(spec, config_name)
  return {
    capabilities = build_capabilities(spec.options),
    outline = function(bufnr, target)
      return spec.builder.build(bufnr, target, {
        filetype = config_name,
        query_text = spec.query_text,
        options = spec.options,
      })
    end,
  }
end

-- ─── user handler state ───────────────────────────────────────────────────────

local USER_SPECS = {}

-- A spec is "complete" (= self-contained, no built-in to merge from) if it
-- supplies the three pieces a builder needs. Partial-override specs are
-- allowed to omit any of these because the built-in fills them in.
local function spec_is_complete(spec)
  return type(spec.builder) == "table"
    and type(spec.query_text) == "string"
    and type(spec.filetypes) == "table"
    and #spec.filetypes > 0
end

local function resolve_user_spec(config_name, user_spec)
  local built_in = BUILT_IN_BY_CONFIG_NAME[config_name]
  if built_in then
    local base = load_built_in_spec(built_in, config_name)
    if not base then
      return nil
    end
    local merged = vim.tbl_deep_extend("force", base, user_spec)
    -- `filetypes` is a list; vim.tbl_deep_extend treats lists as dicts and
    -- would index-merge them. Replace explicitly when the user supplied one.
    if user_spec.filetypes then
      merged.filetypes = user_spec.filetypes
    end
    return merged
  end
  -- No matching built-in → user spec must be self-sufficient.
  if not spec_is_complete(user_spec) then
    return nil
  end
  return user_spec
end

-- ─── filetype → entry table ───────────────────────────────────────────────────

-- Rebuilt every time set_user_handlers is called. Each entry is either a
-- built-in pointer (just (config_name, builder)) or a resolved user spec.
local FILETYPE_TABLE = {}

local function rebuild_filetype_table()
  FILETYPE_TABLE = {}
  -- Built-ins first.
  for _, builder in ipairs(BUILT_IN_BUILDERS) do
    for filetype, config_name in pairs(builder.filetypes or {}) do
      FILETYPE_TABLE[filetype] = {
        source = "built_in",
        config_name = config_name,
        builder = builder,
      }
    end
  end
  -- User specs override / add.
  for config_name, user_spec in pairs(USER_SPECS) do
    local resolved = resolve_user_spec(config_name, user_spec)
    if resolved then
      for _, filetype in ipairs(resolved.filetypes or {}) do
        FILETYPE_TABLE[filetype] = {
          source = "user",
          config_name = config_name,
          spec = resolved,
        }
      end
    end
  end
end

rebuild_filetype_table()

---@param specs table<string, table>|nil
function M.set_user_handlers(specs)
  USER_SPECS = specs or {}
  rebuild_filetype_table()
end

---@param filetype string
---@return table|nil
function M.get(filetype)
  local entry = FILETYPE_TABLE[filetype]
  if not entry then
    return nil
  end
  if entry.source == "built_in" then
    local spec = load_built_in_spec(entry.builder, entry.config_name)
    if not spec then
      return nil
    end
    return spec_to_handler(spec, entry.config_name)
  end
  -- entry.source == "user"
  return spec_to_handler(entry.spec, entry.config_name)
end

return M
