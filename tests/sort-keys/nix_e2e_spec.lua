-- Smoke-level cover of the full :SortKeys pipeline on a real nix buffer:
-- attrset / rec_attrset / let / list / formals / inherit (pinned + inner
-- sort) / comment_attach. Each spec sets up its own buffer; the cursor
-- placement targets the specific container being sorted.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "nix"
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

describe("nix end-to-end via :SortKeys", function()
  local has_nix

  before_each(function()
    has_nix = ts.has_parser("nix")

    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil

    require("sort-keys.config").setup({})

    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  describe("attrset", function()
    it("sorts bindings by attrpath with `;` separator preserved", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "{ b = 2; a = 1; c = 3; }" })
      set_cursor(bufnr, 0, 2)
      vim.cmd("SortKeys")
      assert.equals("{ a = 1; b = 2; c = 3; }", lines_of(bufnr)[1])
    end)
  end)

  describe("rec_attrset", function()
    it("sorts rec attrset bindings even when later bindings reference earlier ones", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      -- Nix is lazy so the b/a reorder is semantically safe; the readability
      -- trade-off is intentionally on the user.
      local bufnr = setup_buf({ "rec { b = a + 1; a = 1; }" })
      set_cursor(bufnr, 0, 6)
      vim.cmd("SortKeys")
      assert.equals("rec { a = 1; b = a + 1; }", lines_of(bufnr)[1])
    end)
  end)

  describe("let bindings", function()
    it("sorts the let binding_set in place, leaving the body untouched", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "let b = 2; a = 1; in a + b" })
      set_cursor(bufnr, 0, 4)
      vim.cmd("SortKeys")
      assert.equals("let a = 1; b = 2; in a + b", lines_of(bufnr)[1])
    end)
  end)

  describe("list", function()
    it("sorts list elements by their surface text with whitespace gaps preserved", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "x = [ c b a ]" })
      set_cursor(bufnr, 0, 6)
      vim.cmd("SortKeys")
      assert.equals("x = [ a b c ]", lines_of(bufnr)[1])
    end)
  end)

  describe("formals", function()
    it("sorts function formal args while keeping `...` pinned at the tail", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "{ f = { c, a, b ? 1, ... }: a + c; }" })
      set_cursor(bufnr, 0, 8)
      vim.cmd("SortKeys")
      assert.equals("{ f = { a, b ? 1, c, ... }: a + c; }", lines_of(bufnr)[1])
    end)
  end)

  describe("inherit (pinned + inner sort)", function()
    it("keeps the inherit binding in place but sorts the identifier list inside", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      -- Cursor inside the inherited_attrs span so the inner array container
      -- (not the outer attrset) is selected.
      local bufnr = setup_buf({ "{ inherit c a b; }" })
      set_cursor(bufnr, 0, 11)
      vim.cmd("SortKeys")
      assert.equals("{ inherit a b c; }", lines_of(bufnr)[1])
    end)

    it("sorts inherit_from identifiers the same way", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = setup_buf({ "{ inherit (pkgs) stdenv lib; }" })
      set_cursor(bufnr, 0, 18)
      vim.cmd("SortKeys")
      assert.equals("{ inherit (pkgs) lib stdenv; }", lines_of(bufnr)[1])
    end)

    it("sorts inherit identifiers when the cursor is on the `inherit` keyword itself", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      -- Without exposing the `inherit` node as a container, the cursor on
      -- the keyword falls through to the outer attrset (which has only one
      -- binding and either no-ops or sorts the wrong scope). Users expect
      -- placing the cursor anywhere on the `inherit ...;` line — including
      -- on the keyword or the source `(expr)` — to sort the identifier
      -- list.
      local bufnr = setup_buf({ "{ inherit c a b; }" })
      set_cursor(bufnr, 0, 3)
      vim.cmd("SortKeys")
      assert.equals("{ inherit a b c; }", lines_of(bufnr)[1])
    end)

    it("sorts inherit_from identifiers when the cursor is on the source `(expr)`", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      -- For `inherit (e) ...`, the user often clicks on the source
      -- expression `(e)` since that's the chunk being edited; the inner
      -- identifier sort must still trigger there.
      local bufnr = setup_buf({ "{ inherit (pkgs) stdenv lib; }" })
      set_cursor(bufnr, 0, 12)
      vim.cmd("SortKeys")
      assert.equals("{ inherit (pkgs) lib stdenv; }", lines_of(bufnr)[1])
    end)
  end)

  describe("comments travel with their entry", function()
    it("keeps a leading `# comment` glued to the binding it documents", function()
      if not has_nix then
        pending("nix treesitter parser not available")
        return
      end
      local bufnr = setup_buf({
        "{",
        "  # leading for b",
        "  b = 2;",
        "  # leading for a",
        "  a = 1;",
        "}",
      })
      set_cursor(bufnr, 0, 0)
      vim.cmd("SortKeys")
      assert.same({
        "{",
        "  # leading for a",
        "  a = 1;",
        "  # leading for b",
        "  b = 2;",
        "}",
      }, lines_of(bufnr))
    end)
  end)
end)
