local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality
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

T["json"] = new_set()

-- Basic SortKeys
T["json"]["SortKeys sorts object keys alphabetically"] = function()
    local input = [[{
    "zebra": 1,
    "apple": 2,
    "mango": 3
}]]
    local expected = [[{
    "apple": 2,
    "mango": 3,
    "zebra": 1
}]]
    local result = helpers.run_sort(child, input, "json", "SortKeys")
    eq(result, expected)
end

T["json"]["SortKeys sorts array elements alphabetically"] = function()
    local input = '["zebra", "apple", "mango"]'
    local expected = '["apple", "mango", "zebra"]'
    local result = helpers.run_sort(child, input, "json", "SortKeys")
    eq(result, expected)
end

-- SortKeys! (reverse)
T["json"]["SortKeys! sorts in reverse order"] = function()
    local input = [[{
    "apple": 1,
    "mango": 2,
    "zebra": 3
}]]
    local expected = [[{
    "zebra": 3,
    "mango": 2,
    "apple": 1
}]]
    local result = helpers.run_sort(child, input, "json", "SortKeys!")
    eq(result, expected)
end

-- DeepSortKeys
T["json"]["DeepSortKeys sorts nested objects"] = function()
    local input = [[{
    "outer_z": {
        "inner_z": 1,
        "inner_a": 2
    },
    "outer_a": {
        "inner_z": 3,
        "inner_a": 4
    }
}]]
    local expected = [[{
    "outer_a": {
        "inner_a": 4,
        "inner_z": 3
    },
    "outer_z": {
        "inner_a": 2,
        "inner_z": 1
    }
}]]
    local result = helpers.run_sort(child, input, "json", "DeepSortKeys")
    eq(result, expected)
end

-- DeepSortKeys!
T["json"]["DeepSortKeys! sorts nested objects in reverse"] = function()
    local input = [[{
    "outer_a": {
        "inner_a": 1,
        "inner_z": 2
    },
    "outer_z": {
        "inner_a": 3,
        "inner_z": 4
    }
}]]
    local expected = [[{
    "outer_z": {
        "inner_z": 4,
        "inner_a": 3
    },
    "outer_a": {
        "inner_z": 2,
        "inner_a": 1
    }
}]]
    local result = helpers.run_sort(child, input, "json", "DeepSortKeys!")
    eq(result, expected)
end

-- Comment tests moved to javascript_spec.lua (JSON doesn't support comments)

-- Numeric sort
T["json"]["SortKeys with numeric flag"] = function()
    local input = [[{
    "item10": 1,
    "item2": 2,
    "item1": 3
}]]
    local expected = [[{
    "item1": 3,
    "item2": 2,
    "item10": 1
}]]
    local result = helpers.run_sort(child, input, "json", "SortKeys n")
    eq(result, expected)
end

-- Case insensitive sort
T["json"]["SortKeys with case insensitive flag"] = function()
    local input = [[{
    "Zebra": 1,
    "apple": 2,
    "Mango": 3
}]]
    local expected = [[{
    "apple": 2,
    "Mango": 3,
    "Zebra": 1
}]]
    local result = helpers.run_sort(child, input, "json", "SortKeys i")
    eq(result, expected)
end

-- Unique flag
T["json"]["SortKeys with unique flag removes duplicates"] = function()
    local input = [[{
    "apple": 1,
    "apple": 2,
    "banana": 3
}]]
    local expected = [[{
    "apple": 1,
    "banana": 3
}]]
    local result = helpers.run_sort(child, input, "json", "SortKeys u")
    eq(result, expected)
end

return T
