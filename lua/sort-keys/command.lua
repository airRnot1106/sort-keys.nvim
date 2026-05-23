-- Cmdline [range] is intentionally ignored; targets come from cursor / visual
-- marks only, so :SortKeys behaves the same whether invoked with or without a
-- :%/range prefix.

local config = require("sort-keys.config")
local target_mod = require("sort-keys.core.target")
local registry = require("sort-keys.core.registry")
local policy = require("sort-keys.core.policy")
local walker = require("sort-keys.core.walker")
local applier = require("sort-keys.core.applier")

local M = {}

-- ─── flag parsing ──────────────────────────────────────────────────────

local TIER1_FLAGS = {
  ["!"] = "reverse",
  ["i"] = "ignore_case",
  ["n"] = "numeric",
  ["u"] = "unique",
}

local function extract_regex_flag(args)
  local pat = args:match("r%s*/(.-)/")
  if pat then
    return pat, (args:gsub("r%s*/.-/", "", 1))
  end
  return nil, args
end

---@param opts { bang: boolean, args: string }
---@return table
function M.parse_args(opts)
  local flags = {}
  if opts.bang then
    flags.reverse = true
  end

  local regex_pat, rest = extract_regex_flag(opts.args or "")
  if regex_pat then
    flags.regex = regex_pat
  end

  for c in rest:gmatch("[!a-zA-Z]") do
    local name = TIER1_FLAGS[c]
    if name then
      flags[name] = true
    end
    -- Unrecognized chars (including the deferred b/o/x/f/l flags) are
    -- silently ignored so users can paste a full :sort line into :SortKeys
    -- without it bailing on unknown flags.
  end

  return flags
end

-- ─── target resolution ─────────────────────────────────────────────────

local function visual_marks_match_cmd_range(opts)
  if (opts.range or 0) == 0 then
    return false
  end
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  return vstart[2] == opts.line1 and vend[2] == opts.line2 and vstart[2] > 0
end

local function selection_target_from_marks()
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  local srow = vstart[2] - 1
  local scol = vstart[3] - 1
  local erow = vend[2] - 1
  local ecol = vend[3] - 1
  return target_mod.from_visual({ srow, scol, erow, ecol })
end

local function cursor_target_now()
  local pos = vim.api.nvim_win_get_cursor(0)
  return target_mod.from_normal({ pos[1] - 1, pos[2] })
end

local function resolve_target(opts)
  if visual_marks_match_cmd_range(opts) then
    return selection_target_from_marks()
  end
  return cursor_target_now()
end

-- ─── dispatch ──────────────────────────────────────────────────────────

local function notify_warn(msg)
  vim.notify(msg, vim.log.levels.WARN, { title = "sort-keys" })
end

local function build_sort_opts(flags, deep)
  return {
    flags = flags,
    normalize_keys = config.options.normalize_keys,
    comparator = config.options.comparator,
    deep = deep,
  }
end

---@param opts table  -- user_command opts
---@param deep boolean
function M.execute(opts, deep)
  local flags = M.parse_args(opts)
  local target = resolve_target(opts)

  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype

  local handler = registry.get(ft)
  if not handler then
    notify_warn(string.format("no handler for filetype %q", ft))
    return
  end

  local outline = handler.outline(bufnr, target)
  if not outline then
    notify_warn("no sortable structure under cursor")
    return
  end

  if target.kind == "selection" then
    outline = policy.apply_selection_overlay(outline, target.range)
  end

  local sorted = walker.walk(outline, build_sort_opts(flags, deep))
  applier.apply(bufnr, sorted)
end

return M
