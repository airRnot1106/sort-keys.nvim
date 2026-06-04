-- The "transform" stage and the heart of the Sort abstraction: compose the
-- three orthogonal axes (order x placement x traverse) into a single IR -> IR
-- function. Sort never touches framing/separator fields; it only permutes
-- entries within each container.

local order = require("sort-keys.core.order")
local placement = require("sort-keys.core.placement")
local traverse = require("sort-keys.core.traverse")
local ir = require("sort-keys.core.ir")

local M = {}

---@param request table  -- { order = spec?, deep = bool? }
---@return fun(c: table): table
local function make_sortfn(request)
  local compare = order.build(request.order or {})
  return function(container)
    local arranged = placement.arrange(container.entries, compare)
    return ir.copy_container(container, { entries = arranged })
  end
end

---@param container table
---@param request table  -- { order = spec?, deep = bool? }
---@return table
function M.sort(container, request)
  request = request or {}
  local sortfn = make_sortfn(request)
  if request.deep then
    return traverse.deep(container, sortfn)
  end
  return traverse.shallow(container, sortfn)
end

return M
