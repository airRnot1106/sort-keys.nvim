local normalize = require("sort-keys.languages.ruby.normalize")

describe("languages.ruby.normalize", function()
  it("passes a bare hash_key_symbol name through", function()
    assert.are.equal("name", normalize("name"))
  end)

  it("strips the leading colon off a simple_symbol", function()
    assert.are.equal("name", normalize(":name"))
  end)

  it("strips the quotes off a string key", function()
    assert.are.equal("a-b", normalize('"a-b"'))
  end)
end)
