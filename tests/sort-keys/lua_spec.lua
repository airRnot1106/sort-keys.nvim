local MiniTest = require "mini.test"
local expect = MiniTest.expect
local helpers = require "tests.sort-keys.helpers"

local T = MiniTest.new_set()

T["lua"] = MiniTest.new_set()

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
    local result = helpers.run_sort(input, "lua", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
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
    local result = helpers.run_sort(input, "lua", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
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
    local result = helpers.run_sort(input, "lua", "SortKeys!")
    expect.equality(helpers.join_lines(result), expected)
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
    local result = helpers.run_sort(input, "lua", "DeepSortKeys")
    expect.equality(helpers.join_lines(result), expected)
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
    local result = helpers.run_sort(input, "lua", "DeepSortKeys!")
    expect.equality(helpers.join_lines(result), expected)
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
    local result = helpers.run_sort(input, "lua", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
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
    local result = helpers.run_sort(input, "lua", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
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
    local result = helpers.run_sort(input, "lua", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
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
    local result = helpers.run_sort(input, "lua", "SortKeys n")
    expect.equality(helpers.join_lines(result), expected)
end

return T
