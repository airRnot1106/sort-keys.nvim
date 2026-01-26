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

T["typescript"] = new_set()

-- Basic SortKeys (object)
T["typescript"]["SortKeys sorts object keys alphabetically"] = function()
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
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

-- SortKeys! (reverse)
T["typescript"]["SortKeys! sorts in reverse order"] = function()
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
    local result = helpers.run_sort(child, input, "typescript", "SortKeys!")
    eq(result, expected)
end

-- DeepSortKeys
T["typescript"]["DeepSortKeys sorts nested objects"] = function()
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
    local result = helpers.run_sort(child, input, "typescript", "DeepSortKeys")
    eq(result, expected)
end

-- object_type (interface/type properties)
T["typescript"]["SortKeys sorts interface properties"] = function()
    local input = [[interface User {
    zebra: string;
    apple: number;
    mango: boolean;
}]]
    local expected = [[interface User {
    apple: number;
    mango: boolean;
    zebra: string;
}]]
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

T["typescript"]["SortKeys sorts type alias properties"] = function()
    local input = [[type User = {
    zebra: string;
    apple: number;
    mango: boolean;
};]]
    local expected = [[type User = {
    apple: number;
    mango: boolean;
    zebra: string;
};]]
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

-- formal_parameters (function parameters)
T["typescript"]["SortKeys sorts function parameters"] = function()
    local input = [[function foo(zebra: string, apple: number, mango: boolean) {}]]
    local expected = [[function foo(apple: number, mango: boolean, zebra: string) {}]]
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

T["typescript"]["SortKeys sorts optional parameters"] = function()
    local input = [[function foo(zebra?: string, apple?: number, mango?: boolean) {}]]
    local expected = [[function foo(apple?: number, mango?: boolean, zebra?: string) {}]]
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

-- object_pattern (destructuring)
T["typescript"]["SortKeys sorts destructuring pattern"] = function()
    local input = [[const { zebra, apple, mango } = obj;]]
    local expected = [[const {apple, mango, zebra} = obj;]]
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

-- With comments
T["typescript"]["SortKeys preserves leading comments"] = function()
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
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

T["typescript"]["SortKeys preserves trailing comments"] = function()
    local input = [[const obj = {
    zebra: 1, // zebra comment
    apple: 2, // apple comment
};]]
    local expected = [[const obj = {
    apple: 2, // apple comment
    zebra: 1, // zebra comment
};]]
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

-- Exclude (spread_element)
T["typescript"]["SortKeys keeps spread element in place"] = function()
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
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

-- Exclude (rest_pattern in destructuring)
T["typescript"]["SortKeys keeps rest pattern in place"] = function()
    local input = [[const { zebra, ...rest, apple } = obj;]]
    local expected = [[const {apple, ...rest, zebra} = obj;]]
    local result = helpers.run_sort(child, input, "typescript", "SortKeys")
    eq(result, expected)
end

return T
