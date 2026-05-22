if vim.g.loaded_sort_keys == 1 then
  return
end
vim.g.loaded_sort_keys = 1

vim.api.nvim_create_user_command("SortKeys", function(opts)
  require("sort-keys").sort(opts)
end, {
  range = true,
  desc = "Sort keys in the current buffer or range",
})
