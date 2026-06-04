local normalize = require("sort-keys.languages.elixir.normalize")

describe("languages.elixir.normalize", function()
  it("takes the name before the colon of a keyword key", function()
    assert.are.equal("name", normalize("name: "))
  end)

  it("strips the colon off an atom and quotes off a string", function()
    assert.are.equal("name", normalize(":name"))
    assert.are.equal("a-b", normalize('"a-b"'))
  end)
end)
