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

T["lua"] = new_set()

-- Basic SortKeys
T["lua"]["SortKeys sorts table keys alphabetically"] = function()
    local input = [[local t = {
    zebra = 1,
    apple = 2,
    mango = 3,
}]]
    local expected = [[local t = {
    apple = 2,
    mango = 3,
    zebra = 1,
}]]
    local result = helpers.run_sort(child, input, "lua", "SortKeys")
    eq(result, expected)
end

T["lua"]["SortKeys sorts string keys"] = function()
    local input = [[local t = {
    ["zebra"] = 1,
    ["apple"] = 2,
    ["mango"] = 3,
}]]
    local expected = [[local t = {
    ["apple"] = 2,
    ["mango"] = 3,
    ["zebra"] = 1,
}]]
    local result = helpers.run_sort(child, input, "lua", "SortKeys")
    eq(result, expected)
end

-- SortKeys! (reverse)
T["lua"]["SortKeys! sorts in reverse order"] = function()
    local input = [[local t = {
    apple = 1,
    mango = 2,
    zebra = 3,
}]]
    local expected = [[local t = {
    zebra = 3,
    mango = 2,
    apple = 1,
}]]
    local result = helpers.run_sort(child, input, "lua", "SortKeys!")
    eq(result, expected)
end

-- DeepSortKeys
T["lua"]["DeepSortKeys sorts nested tables"] = function()
    local input = [[local t = {
    outer_z = {
        inner_z = 1,
        inner_a = 2,
    },
    outer_a = {
        inner_z = 3,
        inner_a = 4,
    },
}]]
    local expected = [[local t = {
    outer_a = {
        inner_a = 4,
        inner_z = 3,
    },
    outer_z = {
        inner_a = 2,
        inner_z = 1,
    },
}]]
    local result = helpers.run_sort(child, input, "lua", "DeepSortKeys")
    eq(result, expected)
end

-- DeepSortKeys!
T["lua"]["DeepSortKeys! sorts nested tables in reverse"] = function()
    local input = [[local t = {
    outer_a = {
        inner_a = 1,
        inner_z = 2,
    },
    outer_z = {
        inner_a = 3,
        inner_z = 4,
    },
}]]
    local expected = [[local t = {
    outer_z = {
        inner_z = 4,
        inner_a = 3,
    },
    outer_a = {
        inner_z = 2,
        inner_a = 1,
    },
}]]
    local result = helpers.run_sort(child, input, "lua", "DeepSortKeys!")
    eq(result, expected)
end

-- With comments
T["lua"]["SortKeys preserves leading comments"] = function()
    local input = [[local t = {
    -- zebra comment
    zebra = 1,
    -- apple comment
    apple = 2,
}]]
    local expected = [[local t = {
    -- apple comment
    apple = 2,
    -- zebra comment
    zebra = 1,
}]]
    local result = helpers.run_sort(child, input, "lua", "SortKeys")
    eq(result, expected)
end

T["lua"]["SortKeys preserves trailing comments"] = function()
    local input = [[local t = {
    zebra = 1, -- zebra comment
    apple = 2, -- apple comment
}]]
    local expected = [[local t = {
    apple = 2, -- apple comment
    zebra = 1, -- zebra comment
}]]
    local result = helpers.run_sort(child, input, "lua", "SortKeys")
    eq(result, expected)
end

-- Exclude (spread/ellipsis)
T["lua"]["SortKeys keeps ellipsis in place"] = function()
    local input = [[local t = {
    zebra = 1,
    ...,
    apple = 2,
}]]
    local expected = [[local t = {
    apple = 2,
    ...,
    zebra = 1,
}]]
    local result = helpers.run_sort(child, input, "lua", "SortKeys")
    eq(result, expected)
end

-- Numeric sort
T["lua"]["SortKeys with numeric flag"] = function()
    local input = [[local t = {
    item10 = 1,
    item2 = 2,
    item1 = 3,
}]]
    local expected = [[local t = {
    item1 = 3,
    item2 = 2,
    item10 = 1,
}]]
    local result = helpers.run_sort(child, input, "lua", "SortKeys n")
    eq(result, expected)
end

return T
