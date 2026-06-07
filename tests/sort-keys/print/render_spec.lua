local render = require("sort-keys.print.render")

local function leaf(key, text)
  return { sort_key = key, text = text }
end

describe("core.render", function()
  it("joins entries with the observed separator and joint", function()
    local c = {
      prefix = "{ ",
      suffix = " }",
      separator = ",",
      joint = " ",
      trailing = false,
      entries = { leaf("b", '"b": 2'), leaf("a", '"a": 1') },
    }
    assert.are.equal('{ "b": 2, "a": 1 }', render.render(c))
  end)

  it("reproduces a multi-line object with newline+indent joints", function()
    local c = {
      prefix = "{\n  ",
      suffix = "\n}",
      separator = ",",
      joint = "\n  ",
      trailing = false,
      entries = { leaf("b", '"b": 2'), leaf("a", '"a": 1') },
    }
    assert.are.equal('{\n  "b": 2,\n  "a": 1\n}', render.render(c))
  end)

  it("emits a trailing separator only when the source had one", function()
    local entries = { leaf("a", "a"), leaf("b", "b") }
    local base = { prefix = "[", suffix = "]", separator = ",", joint = " ", entries = entries }
    base.trailing = false
    assert.are.equal("[a, b]", render.render(base))
    base.trailing = true
    assert.are.equal("[a, b,]", render.render(base))
  end)

  it(
    "keeps a same-line trailing comment glued to its entry while the separator stays slot-bound",
    function()
      -- "a" carried a `// foo`; after reorder it lands last, so it loses the
      -- comma (slot-bound) but keeps the comment (entry-bound), and "b" — now
      -- non-last — gains the comma.
      local c = {
        prefix = "{\n  ",
        suffix = "\n}",
        separator = ",",
        joint = "\n  ",
        trailing = false,
        entries = {
          { sort_key = "b", text = '"b": 2', tail = "" },
          { sort_key = "a", text = '"a": 1', tail = "  // foo" },
        },
      }
      assert.are.equal('{\n  "b": 2,\n  "a": 1  // foo\n}', render.render(c))
    end
  )

  it("renders a nested child between an entry's pre/post when child is set", function()
    local child = {
      prefix = "{",
      suffix = "}",
      separator = ",",
      joint = " ",
      trailing = false,
      entries = { leaf("x", '"x": 1'), leaf("y", '"y": 2') },
    }
    local c = {
      prefix = "{",
      suffix = "}",
      separator = ",",
      joint = " ",
      trailing = false,
      entries = {
        { sort_key = "k", pre = '"k": ', post = "", child = child },
      },
    }
    assert.are.equal('{"k": {"x": 1, "y": 2}}', render.render(c))
  end)
end)
