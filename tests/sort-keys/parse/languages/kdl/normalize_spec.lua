local normalize = require("sort-keys.parse.languages.kdl.normalize")

describe("languages.kdl.normalize", function()
  it("passes a bare property key through", function()
    assert.are.equal("name", normalize("name"))
  end)

  it("strips quotes off a quoted property key", function()
    assert.are.equal("a-b", normalize('"a-b"'))
  end)
end)
