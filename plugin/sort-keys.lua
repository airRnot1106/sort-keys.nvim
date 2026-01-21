if vim.g.loaded_sort_keys then
  return
end
vim.g.loaded_sort_keys = true

---Parse command arguments for options
---@param args string
---@return SortKeysOptions
local function parse_args(args)
  local opts = {}
  -- Match flags like -i, -n, or combined -in, -ni
  for flag in args:gmatch("%-(%a+)") do
    if flag:match("i") then
      opts.case_sensitive = false
    end
    if flag:match("n") then
      opts.natural_sort = true
    end
  end
  return opts
end

vim.api.nvim_create_user_command("SortKeys", function(cmd_opts)
  local opts = parse_args(cmd_opts.args)
  opts.reverse = cmd_opts.bang
  opts.deep = false

  local range = nil
  if cmd_opts.range > 0 then
    range = {
      start_row = cmd_opts.line1 - 1, -- Convert to 0-indexed
      end_row = cmd_opts.line2 - 1,
    }
  end

  require("sort-keys.commands").sort_keys(opts, range)
end, {
  bang = true,
  range = true,
  nargs = "*",
  desc = "Sort object keys alphabetically (! for reverse, -i for case-insensitive, -n for natural sort)",
})

vim.api.nvim_create_user_command("DeepSortKeys", function(cmd_opts)
  local opts = parse_args(cmd_opts.args)
  opts.reverse = cmd_opts.bang
  opts.deep = true

  local range = nil
  if cmd_opts.range > 0 then
    range = {
      start_row = cmd_opts.line1 - 1,
      end_row = cmd_opts.line2 - 1,
    }
  end

  require("sort-keys.commands").sort_keys(opts, range)
end, {
  bang = true,
  range = true,
  nargs = "*",
  desc = "Recursively sort nested object keys (! for reverse, -i for case-insensitive, -n for natural sort)",
})
