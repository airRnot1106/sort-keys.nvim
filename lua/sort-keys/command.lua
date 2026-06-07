-- The dispatch glue: parse the user command into a Request, then drive the
-- pure pipeline parse(extract) -> transform(sort) -> print(render) -> apply.
-- This is the only place the four stages are wired together.

local config = require("sort-keys.config")
local registry = require("sort-keys.registry")
local extract = require("sort-keys.parse.extract")
local sort = require("sort-keys.transform.sort")
local order = require("sort-keys.transform.order")
local render = require("sort-keys.print.render")
local apply = require("sort-keys.print.apply")

local M = {}

local function notify(msg, level)
  vim.notify("sort-keys: " .. msg, level or vim.log.levels.INFO)
end

-- Parse `:sort`-compatible flags into an order spec. The bang (`!`) reverses;
-- `i`/`n` fold case / compare numerically; `u` keeps only the first of each
-- equal-key run; a `/pat/` selects the substring of each key to compare on.
---@param args string
---@param bang boolean
---@return table
function M.parse_order(args, bang)
  local spec = { reverse = bang == true }
  local pattern = args:match("/(.-)/")
  if pattern and pattern ~= "" then
    spec.pattern = pattern
  end
  local flags = args:gsub("/.-/", "")
  for c in flags:gmatch("%a") do
    if c == "i" then
      spec.ignore_case = true
    elseif c == "n" then
      spec.numeric = true
    elseif c == "u" then
      spec.unique = true
    end
  end
  return spec
end

-- Build the Target from the command invocation: a real range (Visual / :line1,line2)
-- becomes a line-wise selection (extract interprets the row span); otherwise the
-- cursor position is used.
---@param opts table
---@return table
local function target_of(opts)
  if opts.range and opts.range > 0 then
    return { kind = "selection", srow = opts.line1 - 1, erow = opts.line2 - 1 }
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  return { kind = "cursor", pos = { cursor[1] - 1, cursor[2] } }
end

---@param opts table  -- nvim user-command opts (args, bang, range, line1, line2)
---@param deep boolean
function M.run(opts, deep)
  local bufnr = vim.api.nvim_get_current_buf()
  local pack = registry.resolve(vim.bo[bufnr].filetype)
  if not pack then
    notify("no handler for filetype '" .. vim.bo[bufnr].filetype .. "'", vim.log.levels.WARN)
    return
  end

  local order_spec = M.parse_order(opts.args or "", opts.bang)
  -- The configured comparator is the ORDER-axis base swap (see transform/order).
  order_spec.comparator = config.options.comparator
  local request = {
    order = order_spec,
    deep = deep == true,
  }
  if request.order.pattern and not order.valid_pattern(request.order.pattern) then
    notify("ignoring invalid sort pattern /" .. request.order.pattern .. "/", vim.log.levels.WARN)
  end

  -- A custom extractor is third-party-ish code; isolate a throw so a buggy one
  -- (or any extract-stage error) surfaces as a warning instead of an uncaught
  -- stack trace, the same graceful path as "nothing sortable here".
  local ok, outline = pcall(extract.extract, bufnr, target_of(opts), pack, request.deep)
  if not ok then
    notify("extract failed: " .. tostring(outline), vim.log.levels.ERROR)
    return
  end
  if not outline then
    notify("no sortable container here", vim.log.levels.WARN)
    return
  end

  local sorted = sort.sort(outline, request)
  apply.apply(bufnr, sorted, render.render(sorted))
end

return M
