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

T["yaml"] = new_set()

-- Flow mapping tests
T["yaml"]["SortKeys sorts flow mapping keys"] = function()
    local input = [[{zebra: 1, apple: 2, mango: 3}]]
    local expected = [[{apple: 2, mango: 3, zebra: 1}]]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys")
    eq(result, expected)
end

T["yaml"]["SortKeys! sorts flow mapping in reverse"] = function()
    local input = [[{apple: 1, mango: 2, zebra: 3}]]
    local expected = [[{zebra: 3, mango: 2, apple: 1}]]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys!")
    eq(result, expected)
end

-- Flow sequence tests
T["yaml"]["SortKeys sorts flow sequence items"] = function()
    local input = [=[[zebra, apple, mango]]=]
    local expected = [=[[apple, mango, zebra]]=]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys")
    eq(result, expected)
end

T["yaml"]["SortKeys! sorts flow sequence in reverse"] = function()
    local input = [=[[apple, mango, zebra]]=]
    local expected = [=[[zebra, mango, apple]]=]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys!")
    eq(result, expected)
end

-- DeepSortKeys for nested flow mappings
T["yaml"]["DeepSortKeys sorts nested flow mappings"] = function()
    local input = [[{outer_z: {inner_z: 1, inner_a: 2}, outer_a: {inner_z: 3, inner_a: 4}}]]
    local expected = [[{outer_a: {inner_a: 4, inner_z: 3}, outer_z: {inner_a: 2, inner_z: 1}}]]
    local result = helpers.run_sort(child, input, "yaml", "DeepSortKeys")
    eq(result, expected)
end

-- Numeric sort test
T["yaml"]["SortKeys with numeric flag sorts flow mapping numerically"] = function()
    local input = [[{item10: 1, item2: 2, item1: 3}]]
    local expected = [[{item1: 3, item2: 2, item10: 1}]]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys n")
    eq(result, expected)
end

-- Quoted keys test
T["yaml"]["SortKeys handles quoted keys in flow mapping"] = function()
    local input = [[{"zebra": 1, 'apple': 2, mango: 3}]]
    local expected = [[{'apple': 2, mango: 3, "zebra": 1}]]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys")
    eq(result, expected)
end

-- Block mapping tests
T["yaml"]["SortKeys sorts block mapping keys"] = function()
    local input = [[zebra: 1
apple: 2
mango: 3]]
    local expected = [[apple: 2
mango: 3
zebra: 1]]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys")
    eq(result, expected)
end

T["yaml"]["SortKeys! sorts block mapping in reverse"] = function()
    local input = [[apple: 1
mango: 2
zebra: 3]]
    local expected = [[zebra: 3
mango: 2
apple: 1]]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys!")
    eq(result, expected)
end

-- NOTE: Leading comment preservation is not supported for YAML due to tree-sitter structure.
-- Leading comments are placed at the 'stream' level, outside the block_mapping container.
-- Inline/trailing comments (same line) are preserved.

-- Block sequence test
T["yaml"]["SortKeys sorts block sequence items"] = function()
    local input = [[- zebra
- apple
- mango]]
    local expected = [[- apple
- mango
- zebra]]
    local result = helpers.run_sort(child, input, "yaml", "SortKeys")
    eq(result, expected)
end

return T
