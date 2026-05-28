local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

describe("sort-keys.core.applier", function()
  local applier

  before_each(function()
    package.loaded["sort-keys.core.applier"] = nil
    applier = require("sort-keys.core.applier")
  end)

  it("rewrites a single-line JSON object to reflect the Outline's new entry order", function()
    -- Buffer:    { "c": 3, "a": 1, "b": 2 }
    -- positions: 0         1         2
    --            0123456789012345678901234
    --            { "c": 3, "a": 1, "b": 2 }
    local bufnr = make_buf({ '{ "c": 3, "a": 1, "b": 2 }' })

    -- Pre-built Outline whose entries are already in target order: a, b, c.
    local outline = {
      kind = "object",
      range = { 0, 0, 0, 26 },
      separator = ", ",
      entries = {
        {
          kind = "pair",
          sort_key = "a",
          range = { 0, 10, 0, 16 }, -- '"a": 1'
          movable = true,
          anchor = 2,
          attached = {},
          child = nil,
        },
        {
          kind = "pair",
          sort_key = "b",
          range = { 0, 18, 0, 24 }, -- '"b": 2'
          movable = true,
          anchor = 3,
          attached = {},
          child = nil,
        },
        {
          kind = "pair",
          sort_key = "c",
          range = { 0, 2, 0, 8 }, -- '"c": 3'
          movable = true,
          anchor = 1,
          attached = {},
          child = nil,
        },
      },
    }

    applier.apply(bufnr, outline)

    local lines = get_lines(bufnr)
    assert.equals(1, #lines)
    assert.equals('{ "a": 1, "b": 2, "c": 3 }', lines[1])
  end)

  it("rewrites a JSON array to reflect the Outline's new element order", function()
    -- Buffer: [ "c", "a", "b" ]
    --         0123456789012345
    local bufnr = make_buf({ '[ "c", "a", "b" ]' })

    local outline = {
      kind = "array",
      range = { 0, 0, 0, 17 },
      separator = ", ",
      entries = {
        {
          kind = "element",
          sort_key = "a",
          range = { 0, 7, 0, 10 },
          movable = true,
          anchor = 2,
          attached = {},
        },
        {
          kind = "element",
          sort_key = "b",
          range = { 0, 12, 0, 15 },
          movable = true,
          anchor = 3,
          attached = {},
        },
        {
          kind = "element",
          sort_key = "c",
          range = { 0, 2, 0, 5 },
          movable = true,
          anchor = 1,
          attached = {},
        },
      },
    }

    applier.apply(bufnr, outline)
    assert.equals('[ "a", "b", "c" ]', get_lines(bufnr)[1])
  end)

  it("omits entries listed in outline.dropped (deduplicate / `u` flag)", function()
    -- Buffer: [ "b", "a", "b", "a" ]
    --         0         1         2
    --         0123456789012345678901
    -- The `u` flag removed the second "b" and second "a". outline.entries
    -- carries the two survivors in sorted order; outline.dropped carries the
    -- removed pair so the applier can rebuild the container's prefix / gaps /
    -- suffix over the full source partition and emit only the survivors,
    -- instead of letting the dropped bytes leak back via the suffix/gaps.
    local bufnr = make_buf({ '[ "b", "a", "b", "a" ]' })

    local b1 = {
      kind = "element",
      sort_key = "b",
      range = { 0, 2, 0, 5 },
      movable = true,
      anchor = 1,
      attached = {},
    }
    local a2 = {
      kind = "element",
      sort_key = "a",
      range = { 0, 7, 0, 10 },
      movable = true,
      anchor = 2,
      attached = {},
    }
    local b3 = {
      kind = "element",
      sort_key = "b",
      range = { 0, 12, 0, 15 },
      movable = true,
      anchor = 3,
      attached = {},
    }
    local a4 = {
      kind = "element",
      sort_key = "a",
      range = { 0, 17, 0, 20 },
      movable = true,
      anchor = 4,
      attached = {},
    }

    local outline = {
      kind = "array",
      range = { 0, 0, 0, 22 },
      structural_separator = ",",
      trailing_separator_allowed = false,
      entries = { a2, b1 }, -- survivors, sorted
      dropped = { b3, a4 }, -- removed duplicates
    }

    applier.apply(bufnr, outline)
    assert.equals('[ "a", "b" ]', get_lines(bufnr)[1])
  end)

  it("omits dropped entries in a whitespace-gapped (newline) container", function()
    -- Buffer:
    --   [
    --     "b"
    --     "a"
    --     "b"
    --     "a"
    --   ]
    -- Nix-list style: empty structural separator, gaps carry the newline +
    -- indentation. After `u`, only the first "a"/"b" survive.
    local bufnr = make_buf({ "[", '  "b"', '  "a"', '  "b"', '  "a"', "]" })

    local b1 = {
      kind = "element",
      sort_key = "b",
      range = { 1, 2, 1, 5 },
      movable = true,
      anchor = 1,
      attached = {},
    }
    local a2 = {
      kind = "element",
      sort_key = "a",
      range = { 2, 2, 2, 5 },
      movable = true,
      anchor = 2,
      attached = {},
    }
    local b3 = {
      kind = "element",
      sort_key = "b",
      range = { 3, 2, 3, 5 },
      movable = true,
      anchor = 3,
      attached = {},
    }
    local a4 = {
      kind = "element",
      sort_key = "a",
      range = { 4, 2, 4, 5 },
      movable = true,
      anchor = 4,
      attached = {},
    }

    local outline = {
      kind = "array",
      range = { 0, 0, 5, 1 },
      structural_separator = "",
      trailing_separator_allowed = true,
      entries = { a2, b1 },
      dropped = { b3, a4 },
    }

    applier.apply(bufnr, outline)
    assert.same({ "[", '  "a"', '  "b"', "]" }, get_lines(bufnr))
  end)

  describe("delegation to separator_normalize", function()
    -- These cases pin that the applier honors outline.structural_separator
    -- and outline.trailing_separator_allowed without re-deriving them from
    -- anything language-specific. Buffers are crafted to deliberately put a
    -- gap into a state separator_normalize must repair.

    it("inserts the structural separator when the gap is missing it", function()
      -- Buffer:        [ "a" "b" ]   (no comma in the gap)
      --                0123456789012
      local bufnr = make_buf({ '[ "a" "b" ]' })

      local outline = {
        kind = "array",
        range = { 0, 0, 0, 11 },
        separator = ", ",
        structural_separator = ",",
        trailing_separator_allowed = true,
        entries = {
          {
            kind = "element",
            sort_key = "a",
            range = { 0, 2, 0, 5 },
            movable = true,
            anchor = 1,
            attached = {},
          },
          {
            kind = "element",
            sort_key = "b",
            range = { 0, 6, 0, 9 },
            movable = true,
            anchor = 2,
            attached = {},
          },
        },
      }

      applier.apply(bufnr, outline)
      assert.equals('[ "a", "b" ]', get_lines(bufnr)[1])
    end)

    it("strips a trailing separator from the last piece when forbidden", function()
      -- Buffer:        [ "a", "b", ]   (trailing comma included in last piece)
      --                0123456789012345
      local bufnr = make_buf({ '[ "a", "b", ]' })

      local outline = {
        kind = "array",
        range = { 0, 0, 0, 13 },
        separator = ", ",
        structural_separator = ",",
        trailing_separator_allowed = false,
        entries = {
          {
            kind = "element",
            sort_key = "a",
            range = { 0, 2, 0, 5 },
            movable = true,
            anchor = 1,
            attached = {},
          },
          {
            kind = "element",
            sort_key = "b",
            -- Include the trailing comma at col 10 inside this piece so the
            -- "strip last separator" path is exercised.
            range = { 0, 7, 0, 11 },
            movable = true,
            anchor = 2,
            attached = {},
          },
        },
      }

      applier.apply(bufnr, outline)
      assert.equals('[ "a", "b" ]', get_lines(bufnr)[1])
    end)

    it("keeps a trailing separator on the last piece when the language allows it", function()
      -- Same buffer / outline as the strip case but trailing_separator_allowed = true.
      local bufnr = make_buf({ '[ "a", "b", ]' })

      local outline = {
        kind = "array",
        range = { 0, 0, 0, 13 },
        separator = ", ",
        structural_separator = ",",
        trailing_separator_allowed = true,
        entries = {
          {
            kind = "element",
            sort_key = "a",
            range = { 0, 2, 0, 5 },
            movable = true,
            anchor = 1,
            attached = {},
          },
          {
            kind = "element",
            sort_key = "b",
            range = { 0, 7, 0, 11 },
            movable = true,
            anchor = 2,
            attached = {},
          },
        },
      }

      applier.apply(bufnr, outline)
      assert.equals('[ "a", "b", ]', get_lines(bufnr)[1])
    end)

    it("is a no-op when structural_separator is absent (backward compat)", function()
      -- Same buffer, no structural_separator declared: the applier must not
      -- invoke any normalization and the result should match the original
      -- pieces/gaps preservation behavior.
      local bufnr = make_buf({ '[ "a" "b" ]' })

      local outline = {
        kind = "array",
        range = { 0, 0, 0, 11 },
        separator = ", ",
        entries = {
          {
            kind = "element",
            sort_key = "a",
            range = { 0, 2, 0, 5 },
            movable = true,
            anchor = 1,
            attached = {},
          },
          {
            kind = "element",
            sort_key = "b",
            range = { 0, 6, 0, 9 },
            movable = true,
            anchor = 2,
            attached = {},
          },
        },
      }

      applier.apply(bufnr, outline)
      assert.equals('[ "a" "b" ]', get_lines(bufnr)[1])
    end)
  end)
end)
