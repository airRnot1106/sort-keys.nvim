local h = require("sort-keys.core.builder_helpers")
local key_normalize = require("sort-keys.languages.json.key_normalize")
local comment_attach = require("sort-keys.core.comment_attach")

local M = {}

local function find_container_for_node(containers_by_key, node)
  return containers_by_key[h.node_id_key(node)]
end

-- ─── outline construction ──────────────────────────────────────────────

local function build_outline(container, ctx)
  if not h.capability_allows(container.kind, ctx.options) then
    return nil
  end

  local raw = ctx.entries_by_parent[container.node_key] or {}
  local sorted_raw = h.sort_entries_by_position(raw)

  local outline_entries = {}
  for i, e in ipairs(sorted_raw) do
    local entry = {
      kind = e.entry_kind,
      range = e.range,
      movable = true,
      anchor = i,
      attached = {},
      child = nil,
    }

    if e.entry_kind == "pair" then
      if not e.key_node then
        return nil
      end
      local key_text = vim.treesitter.get_node_text(e.key_node, ctx.bufnr)
      entry.sort_key = ctx.key_normalizer(key_text)
      if e.value_node then
        local inner = find_container_for_node(ctx.containers_by_key, e.value_node)
        if inner then
          entry.child = build_outline(inner, ctx)
        end
      end
    else
      local elem_text = vim.treesitter.get_node_text(e.node, ctx.bufnr)
      entry.sort_key = h.normalize_element_text(elem_text)
      local inner = find_container_for_node(ctx.containers_by_key, e.node)
      if inner then
        entry.child = build_outline(inner, ctx)
      end
    end

    outline_entries[#outline_entries + 1] = entry
  end

  if ctx.options.comment_aware then
    local container_comments = ctx.comments_by_parent[container.node_key] or {}
    outline_entries = comment_attach.attach(outline_entries, container_comments)
  end

  local sep, trailing = h.separator_for(container, ctx.options)
  return {
    kind = container.kind,
    range = container.range,
    structural_separator = sep,
    trailing_separator_allowed = trailing,
    entries = outline_entries,
  }
end

-- ─── public entry point ────────────────────────────────────────────────

---@param bufnr integer
---@param target table
---@param config { filetype: string, query_text: string, options: table }
---@return table|nil
function M.build(bufnr, target, config)
  if not h.validate_options(config.options) then
    return nil
  end

  -- Parser availability is environmental: a missing language is not a plugin
  -- bug, so we surface it via the same `nil Outline → notify` path the rest
  -- of the build uses. Query syntax errors below are plugin/user bugs and
  -- are intentionally allowed to propagate.
  --
  -- `options.parser_lang` lets a filetype reuse another language's parser when
  -- its own grammar is a superset (e.g. jsonc reuses the json parser, which
  -- accepts JSON-with-comments as a `(comment)` node).
  local lang = config.options.parser_lang or config.filetype
  local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not parser_ok or parser == nil then
    return nil
  end
  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse(lang, config.query_text)

  local containers, entries, comments, containers_by_key = h.collect_matches(bufnr, root, query)
  if #containers == 0 then
    return nil
  end

  local chosen = h.pick_innermost(containers, target)
  if not chosen then
    return nil
  end

  local ctx = {
    bufnr = bufnr,
    options = config.options,
    key_normalizer = config.key_normalizer or key_normalize,
    containers_by_key = containers_by_key,
    entries_by_parent = h.index_by_parent(entries),
    comments_by_parent = h.index_by_parent(comments),
  }

  return build_outline(chosen, ctx)
end

-- Filetypes this builder serves, each mapped to the canonical config name
-- used to locate its `.toml` and treesitter query at runtime. Declared here
-- (not in the registry) so language-specific routing stays out of core.
M.filetypes = {
  json = "json",
  jsonc = "jsonc",
}

-- Self-declared default normalizer; the registry injects this (or a
-- user override) as config.key_normalizer.
M.key_normalizer = key_normalize

return M
