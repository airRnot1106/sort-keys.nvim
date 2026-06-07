local normalize = require("sort-keys.parse.languages.javascript.normalize")

describe("languages.javascript.normalize", function()
  it("passes a bare identifier key through", function()
    assert.are.equal("alpha", normalize("alpha"))
  end)

  it("strips double quotes off a string key", function()
    assert.are.equal("a-b", normalize('"a-b"'))
  end)

  it("strips single quotes off a string key", function()
    assert.are.equal("a-b", normalize("'a-b'"))
  end)

  it("decodes JS escapes in a string key", function()
    assert.are.equal("a\tb", normalize('"a\\tb"'))
  end)

  it("leaves a numeric key as its text", function()
    assert.are.equal("10", normalize("10"))
  end)
end)
