local normalize = require("sort-keys.parse.languages.yaml.normalize")

describe("languages.yaml.normalize", function()
  it("passes a plain scalar key through", function()
    assert.are.equal("name", normalize("name"))
  end)

  it("strips double quotes and decodes escapes", function()
    assert.are.equal("a\tb", normalize('"a\\tb"'))
  end)

  it("strips single quotes literally, unescaping only ''", function()
    assert.are.equal("a'b", normalize("'a''b'"))
    assert.are.equal("a\\nb", normalize("'a\\nb'"))
  end)
end)
