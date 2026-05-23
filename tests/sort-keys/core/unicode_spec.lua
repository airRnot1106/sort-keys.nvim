-- The NFC implementation is an identity stub for now, so these tests only
-- pin the round-trip contract on the easy half (ASCII + pre-composed UTF-8).
-- Decomposed-input behavior is deliberately not asserted.

describe("sort-keys.core.unicode", function()
  local unicode

  before_each(function()
    package.loaded["sort-keys.core.unicode"] = nil
    unicode = require("sort-keys.core.unicode")
  end)

  describe("nfc(s)", function()
    it("returns a string for an ASCII input", function()
      assert.equals("foo", unicode.nfc("foo"))
    end)

    it("returns a string for an empty input", function()
      assert.equals("", unicode.nfc(""))
    end)

    -- Pre-composed (already-NFC) U+00E9 must round-trip byte-for-byte; the
    -- stub-or-real contract has to agree at least on this easy half.
    it("returns the pre-composed form unchanged", function()
      local pre = "\xC3\xA9" -- "é" U+00E9
      assert.equals(pre, unicode.nfc(pre))
    end)
  end)
end)
