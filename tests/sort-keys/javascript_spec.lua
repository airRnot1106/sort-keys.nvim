local MiniTest = require "mini.test"
local expect = MiniTest.expect
local helpers = require "tests.sort-keys.helpers"

local T = MiniTest.new_set()

T["javascript"] = MiniTest.new_set()

-- Basic SortKeys
T["javascript"]["SortKeys sorts object keys alphabetically"] = function()
    local input = [[const obj = {
    zebra: 1,
    apple: 2,
    mango: 3,
};]]
    local expected = [[const obj = {
    apple: 2,
    mango: 3,
    zebra: 1,
};]]
    local result = helpers.run_sort(input, "javascript", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
end

T["javascript"]["SortKeys sorts array elements alphabetically"] = function()
    local input = 'const arr = ["zebra", "apple", "mango"];'
    local expected = 'const arr = ["apple", "mango", "zebra"];'
    local result = helpers.run_sort(input, "javascript", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
end

-- SortKeys! (reverse)
T["javascript"]["SortKeys! sorts in reverse order"] = function()
    local input = [[const obj = {
    apple: 1,
    mango: 2,
    zebra: 3,
};]]
    local expected = [[const obj = {
    zebra: 3,
    mango: 2,
    apple: 1,
};]]
    local result = helpers.run_sort(input, "javascript", "SortKeys!")
    expect.equality(helpers.join_lines(result), expected)
end

-- DeepSortKeys
T["javascript"]["DeepSortKeys sorts nested objects"] = function()
    local input = [[const obj = {
    outer_z: {
        inner_z: 1,
        inner_a: 2,
    },
    outer_a: {
        inner_z: 3,
        inner_a: 4,
    },
};]]
    local expected = [[const obj = {
    outer_a: {
        inner_a: 4,
        inner_z: 3,
    },
    outer_z: {
        inner_a: 2,
        inner_z: 1,
    },
};]]
    local result = helpers.run_sort(input, "javascript", "DeepSortKeys")
    expect.equality(helpers.join_lines(result), expected)
end

-- DeepSortKeys!
T["javascript"]["DeepSortKeys! sorts nested objects in reverse"] = function()
    local input = [[const obj = {
    outer_a: {
        inner_a: 1,
        inner_z: 2,
    },
    outer_z: {
        inner_a: 3,
        inner_z: 4,
    },
};]]
    local expected = [[const obj = {
    outer_z: {
        inner_z: 4,
        inner_a: 3,
    },
    outer_a: {
        inner_z: 2,
        inner_a: 1,
    },
};]]
    local result = helpers.run_sort(input, "javascript", "DeepSortKeys!")
    expect.equality(helpers.join_lines(result), expected)
end

-- With comments
T["javascript"]["SortKeys preserves leading comments"] = function()
    local input = [[const obj = {
    // zebra comment
    zebra: 1,
    // apple comment
    apple: 2,
};]]
    local expected = [[const obj = {
    // apple comment
    apple: 2,
    // zebra comment
    zebra: 1,
};]]
    local result = helpers.run_sort(input, "javascript", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
end

T["javascript"]["SortKeys preserves trailing comments"] = function()
    local input = [[const obj = {
    zebra: 1, // zebra comment
    apple: 2, // apple comment
};]]
    local expected = [[const obj = {
    apple: 2, // apple comment
    zebra: 1, // zebra comment
};]]
    local result = helpers.run_sort(input, "javascript", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
end

-- Exclude (spread_element)
T["javascript"]["SortKeys keeps spread element in place"] = function()
    local input = [[const obj = {
    zebra: 1,
    ...other,
    apple: 2,
};]]
    local expected = [[const obj = {
    apple: 2,
    ...other,
    zebra: 1,
};]]
    local result = helpers.run_sort(input, "javascript", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
end

-- Exclude (rest_pattern in destructuring)
T["javascript"]["SortKeys keeps rest pattern in place"] = function()
    local input = [[const { zebra, ...rest, apple } = obj;]]
    local expected = [[const {apple, ...rest, zebra} = obj;]]
    local result = helpers.run_sort(input, "javascript", "SortKeys")
    expect.equality(helpers.join_lines(result), expected)
end

-- Numeric sort
T["javascript"]["SortKeys with numeric flag"] = function()
    local input = [[const obj = {
    item10: 1,
    item2: 2,
    item1: 3,
};]]
    local expected = [[const obj = {
    item1: 3,
    item2: 2,
    item10: 1,
};]]
    local result = helpers.run_sort(input, "javascript", "SortKeys n")
    expect.equality(helpers.join_lines(result), expected)
end

return T
