local normalize = require("sort-keys.parse.languages.ruby.normalize")

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

  it("strips the quotes off a quoted symbol so it collates with the bare form", function()
    assert.are.equal("a b", normalize(':"a b"'))
  end)

  it("treats single-quoted escapes literally (Ruby semantics)", function()
    -- '\n' in Ruby single quotes is backslash + n, not a newline.
    assert.are.equal("a\\nb", normalize("'a\\nb'"))
  end)
end)
