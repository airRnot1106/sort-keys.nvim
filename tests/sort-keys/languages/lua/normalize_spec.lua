local normalize = require("sort-keys.languages.lua.normalize")

describe("languages.lua.normalize", function()
  it("passes a bare identifier key through unchanged", function()
    assert.are.equal("alpha", normalize("alpha"))
  end)

  it("strips the quotes off a double-quoted bracket key", function()
    assert.are.equal("a key", normalize('"a key"'))
  end)

  it("strips the quotes off a single-quoted bracket key", function()
    assert.are.equal("a key", normalize("'a key'"))
  end)

  it("decodes escapes in a quoted key so it collates by logical value", function()
    assert.are.equal("a\tb", normalize('"a\\tb"'))
  end)
end)
