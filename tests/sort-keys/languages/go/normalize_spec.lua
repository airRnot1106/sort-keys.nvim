local normalize = require("sort-keys.languages.go.normalize")

describe("languages.go.normalize", function()
  it("passes a bare field name through", function()
    assert.are.equal("Name", normalize("Name"))
  end)

  it("strips quotes off a map key / import path", function()
    assert.are.equal("a/b", normalize('"a/b"'))
  end)

  it("unwraps a raw string", function()
    assert.are.equal("a/b", normalize("`a/b`"))
  end)
end)
