local normalize = require("sort-keys.languages.python.normalize")

describe("languages.python.normalize", function()
  it("strips single quotes off a string key", function()
    assert.are.equal("a-b", normalize("'a-b'"))
  end)

  it("strips double quotes off a string key", function()
    assert.are.equal("a-b", normalize('"a-b"'))
  end)

  it("leaves a numeric key as its text", function()
    assert.are.equal("10", normalize("10"))
  end)

  it("decodes shared escapes in a string key", function()
    assert.are.equal("a\tb", normalize("'a\\tb'"))
  end)
end)
