local normalize = require("sort-keys.parse.languages.gleam.normalize")

describe("languages.gleam.normalize", function()
  it("passes a bare argument label through", function()
    assert.are.equal("label", normalize("label"))
  end)
end)
