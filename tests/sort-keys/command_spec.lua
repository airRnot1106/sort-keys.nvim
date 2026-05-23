-- `!` (bang) is delivered via `opts.bang`, not through the args string, so
-- bang behavior has to be exercised on a separate code path from the rest of
-- the flag-parsing tests below.

describe("sort-keys.command — parse_args", function()
  local command

  before_each(function()
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.config"] = nil
    command = require("sort-keys.command")
  end)

  describe("empty args + no bang", function()
    it("returns all five Tier-1 flags as their default falsy value", function()
      local flags = command.parse_args({ bang = false, args = "" })
      assert.is_falsy(flags.reverse)
      assert.is_falsy(flags.ignore_case)
      assert.is_falsy(flags.numeric)
      assert.is_falsy(flags.regex)
      assert.is_falsy(flags.unique)
    end)
  end)

  describe("Tier-1 single flags", function()
    it("opts.bang = true → flags.reverse = true (`!`)", function()
      local flags = command.parse_args({ bang = true, args = "" })
      assert.is_true(flags.reverse)
    end)

    it("args = 'i' → flags.ignore_case = true", function()
      local flags = command.parse_args({ bang = false, args = "i" })
      assert.is_true(flags.ignore_case)
    end)

    it("args = 'n' → flags.numeric = true", function()
      local flags = command.parse_args({ bang = false, args = "n" })
      assert.is_true(flags.numeric)
    end)

    it("args = 'u' → flags.unique = true", function()
      local flags = command.parse_args({ bang = false, args = "u" })
      assert.is_true(flags.unique)
    end)

    it("args = 'r /\\d+/' → flags.regex is the inner pattern", function()
      local flags = command.parse_args({ bang = false, args = "r /\\d+/" })
      assert.equals("\\d+", flags.regex)
    end)
  end)

  describe("compound flags", function()
    it("args = 'iu' + bang → reverse / ignore_case / unique all true", function()
      local flags = command.parse_args({ bang = true, args = "iu" })
      assert.is_true(flags.reverse)
      assert.is_true(flags.ignore_case)
      assert.is_true(flags.unique)
    end)
  end)

  describe("deferred flags — warn-and-ignore", function()
    it("does not raise and does not set any Tier-1 flag for 'b'/'o'/'x'/'f'/'l'", function()
      -- Deferred flags must be a no-op rather than an error so users can
      -- paste full :sort lines verbatim into :SortKeys.
      local flags = command.parse_args({ bang = false, args = "box" })
      assert.is_falsy(flags.reverse)
      assert.is_falsy(flags.ignore_case)
      assert.is_falsy(flags.numeric)
      assert.is_falsy(flags.unique)
    end)
  end)
end)
