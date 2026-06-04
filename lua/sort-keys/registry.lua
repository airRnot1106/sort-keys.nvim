-- Resolves a buffer's filetype to a language pack. A built-in pack is fully
-- declarative: a `config.toml` (capabilities + parser), a `sort-keys.scm`
-- (tree-sitter query), and an optional `normalize.lua` (key normalization),
-- all located on &runtimepath by config name. There is no per-language Lua
-- builder — the generic extractor drives the IR from the query + config.
--
-- User handlers injected via setup({handlers=...}) override or extend the
-- built-ins by config name.

local toml_loader = require("sort-keys.core.toml_loader")

local M = {}

-- filetype -> config_name. New filetypes that reuse an existing pack's parser
-- (e.g. jsonc on the json parser) add an entry here.
local BUILT_IN_FILETYPES = {
  json = "json",
  jsonc = "jsonc",
  lua = "lua",
  javascript = "javascript",
  typescript = "typescript",
  python = "python",
  ruby = "ruby",
  yaml = "yaml",
  pkl = "pkl",
  nix = "nix",
  toml = "toml",
  rust = "rust",
}

local TOML_PATH_FMT = "lua/sort-keys/languages/%s/config.toml"
local QUERY_PATH_FMT = "lua/sort-keys/languages/%s/%s"
local NORMALIZE_MODULE_FMT = "sort-keys.languages.%s.normalize"
local EXTRACTOR_MODULE_FMT = "sort-keys.languages.%s.extractor"

local user_handlers = {}

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
  return vim.api.nvim_get_runtime_file(rel_path, false)[1]
end

-- Loads the built-in declarative pack for a config name off &runtimepath.
-- Memoized: the .toml / .scm ship with the plugin and never change at runtime.
local builtin_cache = {}
local function load_builtin(config_name)
  if builtin_cache[config_name] then
    return builtin_cache[config_name]
  end

  local toml_path = locate_runtime(string.format(TOML_PATH_FMT, config_name))
  if not toml_path then
    return nil
  end
  local options = toml_loader.parse(read_file(toml_path))

  local query_file = options.query_file or "sort-keys.scm"
  local query_path = locate_runtime(string.format(QUERY_PATH_FMT, config_name, query_file))
  if not query_path then
    return nil
  end

  local key_normalizer
  local ok, mod = pcall(require, string.format(NORMALIZE_MODULE_FMT, config_name))
  if ok and type(mod) == "function" then
    key_normalizer = mod
  end

  -- An irregular AST whose container/entry shape the generic query can't tag
  -- ships a custom extractor `languages/<config_name>/extractor.lua`; the
  -- generic extractor is used when there is none.
  local extractor
  local eok, emod = pcall(require, string.format(EXTRACTOR_MODULE_FMT, config_name))
  if eok and type(emod) == "table" and type(emod.extract) == "function" then
    extractor = emod
  end

  local pack = {
    config_name = config_name,
    options = options,
    query_text = read_file(query_path),
    key_normalizer = key_normalizer,
    extractor = extractor,
  }
  builtin_cache[config_name] = pack
  return pack
end

---Replace the user-handler map wholesale. Internal; public callers go through
---config.setup. Each spec is keyed by config_name and may carry
---{ filetypes, options, query_text, key_normalizer }.
---@param specs table
function M.set_user_handlers(specs)
  user_handlers = specs or {}
end

-- The built-in filetypes a config_name serves (reverse of BUILT_IN_FILETYPES).
local function builtin_filetypes_for(config_name)
  local fts = {}
  for ft, cn in pairs(BUILT_IN_FILETYPES) do
    if cn == config_name then
      fts[#fts + 1] = ft
    end
  end
  return fts
end

-- filetype -> user spec. A spec keyed by a built-in config_name with no
-- explicit filetypes is a partial override and inherits the built-in's
-- filetypes, so supplying only `options` actually binds. An explicit
-- `filetypes` list always wins (extend/replace specific filetypes).
local function user_filetype_index()
  local index = {}
  for config_name, spec in pairs(user_handlers) do
    local fts = spec.filetypes
    if not fts or #fts == 0 then
      fts = builtin_filetypes_for(config_name)
    end
    for _, ft in ipairs(fts) do
      index[ft] = { config_name = config_name, spec = spec }
    end
  end
  return index
end

---Resolve a filetype to a ready-to-use pack, or nil if unsupported.
---@param filetype string
---@return table|nil
function M.resolve(filetype)
  local user_index = user_filetype_index()
  local hit = user_index[filetype]
  if hit then
    local base = load_builtin(hit.config_name) or {}
    local spec = hit.spec
    return {
      config_name = hit.config_name,
      options = vim.tbl_deep_extend("force", base.options or {}, spec.options or {}),
      query_text = spec.query_text or base.query_text,
      key_normalizer = spec.key_normalizer or base.key_normalizer,
      extractor = spec.extractor or base.extractor,
    }
  end

  local config_name = BUILT_IN_FILETYPES[filetype]
  if not config_name then
    return nil
  end
  return load_builtin(config_name)
end

return M
