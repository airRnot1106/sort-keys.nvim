local M = {}

function M.check()
  vim.health.start("sort-keys")
  vim.health.ok("sort-keys is loaded")
end

return M
