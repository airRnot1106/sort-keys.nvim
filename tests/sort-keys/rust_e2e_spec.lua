-- Smoke-level cover of the full :SortKeys / :DeepSortKeys pipeline on a real
-- rust buffer: struct definition, struct literal, use_list, struct-update
-- pinning (`..base`), attribute-travels-with-field (the Rust-specific
-- delegation), and deep recursion.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "rust"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(bufnr, row, col)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(win, { row + 1, col })
  return bufnr
end

describe("rust end-to-end via :SortKeys", function()
  local has_rust

  before_each(function()
    has_rust = ts.has_parser("rust")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("struct definition", function()
    it("sorts struct fields by identifier", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "struct Foo {",
        "    version: u32,",
        "    name: String,",
        "    age: u32,",
        "}",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("SortKeys")
      assert.same({
        "struct Foo {",
        "    age: u32,",
        "    name: String,",
        "    version: u32,",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("struct literal", function()
    it("sorts struct-literal field initializers", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "fn make() -> Foo {",
        "    Foo {",
        "        c: 3,",
        "        a: 1,",
        "        b: 2,",
        "    }",
        "}",
      })
      set_cursor(bufnr, 2, 8)
      vim.cmd("SortKeys")
      assert.same({
        "fn make() -> Foo {",
        "    Foo {",
        "        a: 1,",
        "        b: 2,",
        "        c: 3,",
        "    }",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("use_list", function()
    it("sorts grouped imports by surface text", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "use std::collections::{HashMap, BTreeMap, HashSet};",
      })
      set_cursor(bufnr, 0, 25)
      vim.cmd("SortKeys")
      assert.same({
        "use std::collections::{BTreeMap, HashMap, HashSet};",
      }, lines_of(bufnr))
    end)
  end)

  describe("struct-update `..base` stays at its position", function()
    it("does not reorder `..base` past the explicit fields", function()
      -- The Rust grammar requires the base initializer to trail the explicit
      -- fields. `base_field_initializer` is movable=false at anchor 3, so
      -- the two real fields swap and `..base` stays put.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "fn make() -> Foo {",
        "    Foo {",
        "        b: 2,",
        "        a: 1,",
        "        ..base",
        "    }",
        "}",
      })
      set_cursor(bufnr, 2, 8)
      vim.cmd("SortKeys")
      assert.same({
        "fn make() -> Foo {",
        "    Foo {",
        "        a: 1,",
        "        b: 2,",
        "        ..base",
        "    }",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("attributes travel with their field", function()
    it("keeps `#[serde(...)]` attached to its field after a reorder", function()
      -- The whole point of routing attribute_item through @sortkeys.comment:
      -- without it, sorting `b` above `a` would silently leave the rename
      -- attribute on the wrong field.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "struct Foo {",
        '    #[serde(rename = "B")]',
        "    b: u32,",
        "    a: u32",
        "}",
      })
      set_cursor(bufnr, 2, 4)
      vim.cmd("SortKeys")
      assert.same({
        "struct Foo {",
        "    a: u32,",
        '    #[serde(rename = "B")]',
        "    b: u32",
        "}",
      }, lines_of(bufnr))
    end)

    it("keeps `#[cfg(test)]` attached to a shorthand-field initializer after a reorder", function()
      -- shorthand_field_initializer is the second AST shape in struct-literal
      -- bodies that takes attribute_item as a child. Same coverage check as
      -- the regular field_initializer above.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "fn make() -> Foo {",
        "    Foo {",
        "        #[cfg(test)]",
        "        b,",
        "        a,",
        "    }",
        "}",
      })
      set_cursor(bufnr, 2, 8)
      vim.cmd("SortKeys")
      assert.same({
        "fn make() -> Foo {",
        "    Foo {",
        "        a,",
        "        #[cfg(test)]",
        "        b,",
        "    }",
        "}",
      }, lines_of(bufnr))
    end)

    it("carries a comment that sits between attribute and struct-literal field", function()
      -- Parser parses the in-between line_comment as another CHILD of the
      -- field_initializer, so the entry's range covers attribute + comment +
      -- field as one chunk.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "fn make() -> Foo {",
        "    Foo {",
        '        #[serde(rename = "B")]',
        "        // note for b",
        "        b: 2,",
        "        a: 1,",
        "    }",
        "}",
      })
      set_cursor(bufnr, 2, 8)
      vim.cmd("SortKeys")
      assert.same({
        "fn make() -> Foo {",
        "    Foo {",
        "        a: 1,",
        '        #[serde(rename = "B")]',
        "        // note for b",
        "        b: 2,",
        "    }",
        "}",
      }, lines_of(bufnr))
    end)

    it("keeps `#[serde(...)]` attached to a struct-literal field after a reorder", function()
      -- Struct-literal `field_initializer` parses attribute_item as its CHILD
      -- (not as a sibling in the field_initializer_list, the way struct
      -- DEFINITIONS do). The entry's range naturally covers the attribute,
      -- so the applier moves the attribute with the field — but this only
      -- works if comment_attach does NOT also reattach the attribute to a
      -- different entry. This test pins both ends.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "fn make() -> Foo {",
        "    Foo {",
        '        #[serde(rename = "B")]',
        "        b: 2,",
        "        a: 1,",
        "    }",
        "}",
      })
      set_cursor(bufnr, 2, 8)
      vim.cmd("SortKeys")
      assert.same({
        "fn make() -> Foo {",
        "    Foo {",
        "        a: 1,",
        '        #[serde(rename = "B")]',
        "        b: 2,",
        "    }",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe("tuple-struct field initializer (`Foo { 0: x, 1: y }`)", function()
    it("does not lose entries or corrupt the buffer when integer-keyed", function()
      -- The struct-literal syntax for tuple structs uses integer field names
      -- (`Pair { 0: a, 1: b }`). These parse as `field_initializer` whose first
      -- child is `integer_literal`, not `field_identifier`. The builder must
      -- still account for them — at minimum they must be captured so the
      -- applier doesn't rewrite the container with zero entries.
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "fn make() -> Pair {",
        "    Pair { 1: 20, 0: 10 }",
        "}",
      })
      set_cursor(bufnr, 1, 12)
      vim.cmd("SortKeys")
      -- Integer field names are semantically positional — reordering them
      -- across siblings would surprise the user, and naive string ordering
      -- would put `10` between `1` and `2`. Pinning them (movable=false)
      -- preserves source order and is safe; that's what the spec asserts.
      assert.same({
        "fn make() -> Pair {",
        "    Pair { 1: 20, 0: 10 }",
        "}",
      }, lines_of(bufnr))
    end)
  end)

  describe(":DeepSortKeys", function()
    it("recurses into a nested struct-literal value before sorting the outer fields", function()
      if not has_rust then
        pending("rust treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "fn make() -> Outer {",
        "    Outer {",
        "        z: Inner {",
        "            y: 2,",
        "            x: 1,",
        "        },",
        "        a: 1,",
        "    }",
        "}",
      })
      set_cursor(bufnr, 1, 4)
      vim.cmd("DeepSortKeys")
      assert.same({
        "fn make() -> Outer {",
        "    Outer {",
        "        a: 1,",
        "        z: Inner {",
        "            x: 1,",
        "            y: 2,",
        "        },",
        "    }",
        "}",
      }, lines_of(bufnr))
    end)
  end)
end)
