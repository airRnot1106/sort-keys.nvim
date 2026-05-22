local config = require("sort-keys.config")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

function M.sort(opts)
  -- TODO: implement key sorting for the current buffer or the given range.
  local _ = opts
end

return M
