local MiniTest = require "mini.test"
local expect = MiniTest.expect

local T = MiniTest.new_set {
    hooks = {
        pre_case = function()
            -- Load the module fresh for each test
            package.loaded["sort-keys.core.comparator"] = nil
        end,
    },
}

local comparator = require "sort-keys.core.comparator"

T["create_comparator"] = MiniTest.new_set()

T["create_comparator"]["sorts alphabetically by default"] = function()
    local flags = { case_insensitive = false, numeric_mode = nil, unique = false }
    local compare = comparator.create_comparator(flags, false)

    local items = {
        { key_text = "zebra" },
        { key_text = "apple" },
        { key_text = "mango" },
    }
    table.sort(items, compare)

    expect.equality(items[1].key_text, "apple")
    expect.equality(items[2].key_text, "mango")
    expect.equality(items[3].key_text, "zebra")
end

T["create_comparator"]["sorts in reverse order"] = function()
    local flags = { case_insensitive = false, numeric_mode = nil, unique = false }
    local compare = comparator.create_comparator(flags, true)

    local items = {
        { key_text = "apple" },
        { key_text = "zebra" },
        { key_text = "mango" },
    }
    table.sort(items, compare)

    expect.equality(items[1].key_text, "zebra")
    expect.equality(items[2].key_text, "mango")
    expect.equality(items[3].key_text, "apple")
end

T["create_comparator"]["sorts case-insensitively"] = function()
    local flags = { case_insensitive = true, numeric_mode = nil, unique = false }
    local compare = comparator.create_comparator(flags, false)

    local items = {
        { key_text = "Zebra" },
        { key_text = "apple" },
        { key_text = "Mango" },
    }
    table.sort(items, compare)

    expect.equality(items[1].key_text, "apple")
    expect.equality(items[2].key_text, "Mango")
    expect.equality(items[3].key_text, "Zebra")
end

T["create_comparator"]["sorts numerically"] = function()
    local flags = { case_insensitive = false, numeric_mode = "decimal", unique = false }
    local compare = comparator.create_comparator(flags, false)

    local items = {
        { key_text = "item10" },
        { key_text = "item2" },
        { key_text = "item1" },
    }
    table.sort(items, compare)

    expect.equality(items[1].key_text, "item1")
    expect.equality(items[2].key_text, "item2")
    expect.equality(items[3].key_text, "item10")
end

T["remove_duplicates"] = MiniTest.new_set()

T["remove_duplicates"]["removes duplicate keys"] = function()
    local elements = {
        { key_text = "apple", value_text = "1" },
        { key_text = "apple", value_text = "2" },
        { key_text = "banana", value_text = "3" },
    }
    local result = comparator.remove_duplicates(elements, false)

    expect.equality(#result, 2)
    expect.equality(result[1].key_text, "apple")
    expect.equality(result[1].value_text, "1")
    expect.equality(result[2].key_text, "banana")
end

T["remove_duplicates"]["removes case-insensitive duplicates"] = function()
    local elements = {
        { key_text = "Apple", value_text = "1" },
        { key_text = "apple", value_text = "2" },
        { key_text = "BANANA", value_text = "3" },
    }
    local result = comparator.remove_duplicates(elements, true)

    expect.equality(#result, 2)
    expect.equality(result[1].key_text, "Apple")
    expect.equality(result[2].key_text, "BANANA")
end

T["sort_with_exclusions"] = MiniTest.new_set()

T["sort_with_exclusions"]["keeps excluded elements in place"] = function()
    local flags = { case_insensitive = false, numeric_mode = nil, unique = false }
    local compare = comparator.create_comparator(flags, false)

    local elements = {
        { key_text = "zebra", is_excluded = false },
        { key_text = nil, is_excluded = true }, -- spread element
        { key_text = "apple", is_excluded = false },
    }
    local result = comparator.sort_with_exclusions(elements, compare)

    expect.equality(result[1].key_text, "apple")
    expect.equality(result[2].is_excluded, true)
    expect.equality(result[3].key_text, "zebra")
end

return T
