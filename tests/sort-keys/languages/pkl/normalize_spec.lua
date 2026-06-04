local normalize = require("sort-keys.languages.pkl.normalize")

describe("languages.pkl.normalize", function()
  it("passes a bare identifier key through", function()
    assert.are.equal("name", normalize("name"))
  end)

  it("strips quotes off an entry string key", function()
    assert.are.equal("a-b", normalize('"a-b"'))
  end)

  it("unwraps a backtick-quoted identifier", function()
    assert.are.equal("weird key", normalize("`weird key`"))
  end)
end)
