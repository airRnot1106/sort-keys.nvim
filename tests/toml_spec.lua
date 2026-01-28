local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local helpers = require "tests.helpers"

-- Create child neovim instance
local child = helpers.new_child_neovim()

local T = new_set {
    hooks = {
        pre_case = function()
            child.setup()
        end,
        post_once = child.stop,
    },
}

T["toml"] = new_set()

-- Inline table tests
T["toml"]["SortKeys sorts inline table keys"] = function()
    local input = [[config = {zebra = 1, apple = 2, mango = 3}]]
    local expected = [[config = {apple = 2, mango = 3, zebra = 1}]]
    local result = helpers.run_sort(child, input, "toml", "SortKeys")
    eq(result, expected)
end

T["toml"]["SortKeys! sorts inline table in reverse"] = function()
    local input = [[config = {apple = 1, mango = 2, zebra = 3}]]
    local expected = [[config = {zebra = 3, mango = 2, apple = 1}]]
    local result = helpers.run_sort(child, input, "toml", "SortKeys!")
    eq(result, expected)
end

-- Array tests
T["toml"]["SortKeys sorts array items"] = function()
    local input = [=[items = ["zebra", "apple", "mango"]]=]
    local expected = [=[items = ["apple", "mango", "zebra"]]=]
    local result = helpers.run_sort(child, input, "toml", "SortKeys")
    eq(result, expected)
end

T["toml"]["SortKeys! sorts array in reverse"] = function()
    local input = [=[items = ["apple", "mango", "zebra"]]=]
    local expected = [=[items = ["zebra", "mango", "apple"]]=]
    local result = helpers.run_sort(child, input, "toml", "SortKeys!")
    eq(result, expected)
end

-- Numeric sort test
T["toml"]["SortKeys with numeric flag sorts inline table numerically"] = function()
    local input = [[config = {item10 = 1, item2 = 2, item1 = 3}]]
    local expected = [[config = {item1 = 3, item2 = 2, item10 = 1}]]
    local result = helpers.run_sort(child, input, "toml", "SortKeys n")
    eq(result, expected)
end

-- Quoted keys test
T["toml"]["SortKeys handles quoted keys in inline table"] = function()
    local input = [[config = {"zebra" = 1, "apple" = 2, "mango" = 3}]]
    local expected = [[config = {"apple" = 2, "mango" = 3, "zebra" = 1}]]
    local result = helpers.run_sort(child, input, "toml", "SortKeys")
    eq(result, expected)
end

-- DeepSortKeys for nested inline tables
T["toml"]["DeepSortKeys sorts nested inline tables"] = function()
    local input = [[config = {outer_z = {inner_z = 1, inner_a = 2}, outer_a = {inner_z = 3, inner_a = 4}}]]
    local expected = [[config = {outer_a = {inner_a = 4, inner_z = 3}, outer_z = {inner_a = 2, inner_z = 1}}]]
    local result = helpers.run_sort(child, input, "toml", "DeepSortKeys")
    eq(result, expected)
end

-- Numeric array sort
T["toml"]["SortKeys sorts numeric array items"] = function()
    local input = [=[numbers = [3, 1, 2]]=]
    local expected = [=[numbers = [1, 2, 3]]=]
    local result = helpers.run_sort(child, input, "toml", "SortKeys")
    eq(result, expected)
end

-- Table section tests (with header)
T["toml"]["SortKeys sorts table section and preserves header"] = function()
    local input = [=[[package]
zebra = "1"
apple = "2"
mango = "3"]=]
    local expected = [=[[package]
apple = "2"
mango = "3"
zebra = "1"]=]
    local result = helpers.run_sort(child, input, "toml", "SortKeys")
    eq(result, expected)
end

T["toml"]["SortKeys! sorts table section in reverse and preserves header"] = function()
    local input = [=[[package]
apple = "1"
mango = "2"
zebra = "3"]=]
    local expected = [=[[package]
zebra = "3"
mango = "2"
apple = "1"]=]
    local result = helpers.run_sort(child, input, "toml", "SortKeys!")
    eq(result, expected)
end

return T
