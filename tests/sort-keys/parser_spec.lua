local MiniTest = require "mini.test"
local expect = MiniTest.expect

local T = MiniTest.new_set {
    hooks = {
        pre_case = function()
            -- Load the module fresh for each test
            package.loaded["sort-keys.core.parser"] = nil
        end,
    },
}

local parser = require "sort-keys.core.parser"

T["parse_flags"] = MiniTest.new_set()

T["parse_flags"]["returns empty flags for empty input"] = function()
    local flags = parser.parse_flags ""
    expect.equality(flags.case_insensitive, false)
    expect.equality(flags.numeric_mode, nil)
    expect.equality(flags.unique, false)
end

T["parse_flags"]["parses case-insensitive flag"] = function()
    local flags = parser.parse_flags "i"
    expect.equality(flags.case_insensitive, true)
end

T["parse_flags"]["parses numeric flag"] = function()
    local flags = parser.parse_flags "n"
    expect.equality(flags.numeric_mode, "decimal")
end

T["parse_flags"]["parses float flag"] = function()
    local flags = parser.parse_flags "f"
    expect.equality(flags.numeric_mode, "float")
end

T["parse_flags"]["parses hex flag"] = function()
    local flags = parser.parse_flags "x"
    expect.equality(flags.numeric_mode, "hex")
end

T["parse_flags"]["parses octal flag"] = function()
    local flags = parser.parse_flags "o"
    expect.equality(flags.numeric_mode, "octal")
end

T["parse_flags"]["parses binary flag"] = function()
    local flags = parser.parse_flags "b"
    expect.equality(flags.numeric_mode, "binary")
end

T["parse_flags"]["parses unique flag"] = function()
    local flags = parser.parse_flags "u"
    expect.equality(flags.unique, true)
end

T["parse_flags"]["parses combined flags"] = function()
    local flags = parser.parse_flags "in"
    expect.equality(flags.case_insensitive, true)
    expect.equality(flags.numeric_mode, "decimal")
end

T["parse_flags"]["ignores whitespace"] = function()
    local flags = parser.parse_flags " i n "
    expect.equality(flags.case_insensitive, true)
    expect.equality(flags.numeric_mode, "decimal")
end

T["parse_range"] = MiniTest.new_set()

T["parse_range"]["returns nil for no range"] = function()
    local range = parser.parse_range(nil, nil)
    expect.equality(range, nil)
end

T["parse_range"]["returns table for valid range"] = function()
    local range = parser.parse_range(10, 20)
    expect.equality(range[1], 10)
    expect.equality(range[2], 20)
end

return T
