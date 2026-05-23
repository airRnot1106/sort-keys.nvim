if vim.g.loaded_sort_keys == 1 then
  return
end
vim.g.loaded_sort_keys = 1

vim.api.nvim_create_user_command("SortKeys", function(opts)
  require("sort-keys.command").execute(opts, false)
end, {
  range = true,
  bang = true,
  nargs = "?",
  desc = "Sort keys in the current buffer or selection",
})

vim.api.nvim_create_user_command("DeepSortKeys", function(opts)
  require("sort-keys.command").execute(opts, true)
end, {
  range = true,
  bang = true,
  nargs = "?",
  desc = "Recursively sort keys in the current buffer or selection",
})
