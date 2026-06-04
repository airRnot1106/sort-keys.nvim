local normalize = require("sort-keys.languages.json.normalize")

describe("languages.json.normalize", function()
  it("strips the surrounding double quotes off a key", function()
    assert.are.equal("name", normalize('"name"'))
  end)

  it("decodes JSON backslash escapes so escaped and literal keys collate alike", function()
    assert.are.equal("a/b", normalize('"a\\/b"'))
    assert.are.equal("tab\there", normalize('"tab\\there"'))
  end)

  it("decodes \\uXXXX escapes to their UTF-8 bytes", function()
    assert.are.equal("é", normalize('"\\u00e9"'))
  end)

  it("leaves already-unquoted text untouched", function()
    assert.are.equal("bare", normalize("bare"))
  end)
end)
