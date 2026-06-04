-- Smoke-checks the fully wired pipeline (extract -> sort -> render -> apply)
-- on real JSON buffers. Skipped when the JSON treesitter parser is absent, so
-- the suite stays green on minimal environments.

local ts = require("tests.support.treesitter")

local function setup_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "json"
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function set_cursor(row, col)
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { row + 1, col })
end

describe("json end-to-end", function()
  local has_json

  before_each(function()
    has_json = ts.has_parser("json")
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it(":SortKeys sorts object keys ascending and rewrites the buffer", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      '  "banana": 1,',
      '  "apple": 2,',
      '  "cherry": 3',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({
      "{",
      '  "apple": 2,',
      '  "banana": 1,',
      '  "cherry": 3',
      "}",
    }, lines_of(bufnr))
  end)

  it(":SortKeys! sorts object keys descending", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      '  "a": 1,',
      '  "b": 2,',
      '  "c": 3',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("SortKeys!")
    assert.are.same({
      "{",
      '  "c": 3,',
      '  "b": 2,',
      '  "a": 1',
      "}",
    }, lines_of(bufnr))
  end)

  it(":SortKeys is shallow — nested objects keep their original order", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      '  "b": { "y": 1, "x": 2 },',
      '  "a": 1',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({
      "{",
      '  "a": 1,',
      '  "b": { "y": 1, "x": 2 }',
      "}",
    }, lines_of(bufnr))
  end)

  it(":DeepSortKeys recurses into nested objects", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      '  "b": { "y": 1, "x": 2 },',
      '  "a": 1',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("DeepSortKeys")
    assert.are.same({
      "{",
      '  "a": 1,',
      '  "b": { "x": 2, "y": 1 }',
      "}",
    }, lines_of(bufnr))
  end)

  it("sorts a single-line object preserving spacing and no trailing comma", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({ '{ "b": 2, "a": 1 }' })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ '{ "a": 1, "b": 2 }' }, lines_of(bufnr))
  end)

  it("honors a custom comparator supplied via setup()", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    -- order by key length, not lexicographically (1 < 2 < 3 chars).
    require("sort-keys.config").setup({
      comparator = function(a, b)
        return #a.sort_key < #b.sort_key
      end,
    })
    local bufnr = setup_buf({
      "{",
      '  "bbb": 1,',
      '  "a": 2,',
      '  "cc": 3',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({
      "{",
      '  "a": 2,',
      '  "cc": 3,',
      '  "bbb": 1',
      "}",
    }, lines_of(bufnr))
  end)

  it("sorts an array of strings", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({ '["banana", "apple", "cherry"]' })
    set_cursor(0, 1)
    vim.cmd("SortKeys")
    assert.are.same({ '["apple", "banana", "cherry"]' }, lines_of(bufnr))
  end)

  it("range :SortKeys sorts only the entries on the selected lines, pinning the rest", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({
      "{",
      '  "c": 3,',
      '  "b": 2,',
      '  "a": 1',
      "}",
    })
    -- select lines 2-3 ("c","b"); "a" on line 4 stays pinned.
    vim.cmd("2,3SortKeys")
    assert.are.same({
      "{",
      '  "b": 2,',
      '  "c": 3,',
      '  "a": 1',
      "}",
    }, lines_of(bufnr))
  end)

  it("range selection covering the indented opening brace still resolves the container", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    -- The inner object's "{" is indented (not at column 0); a line-wise
    -- selection of its lines must still resolve it by row span.
    local bufnr = setup_buf({
      "{",
      '  "z": {',
      '    "b": 2,',
      '    "a": 1',
      "  }",
      "}",
    })
    vim.cmd("2,5SortKeys")
    assert.are.same({
      "{",
      '  "z": {',
      '    "a": 1,',
      '    "b": 2',
      "  }",
      "}",
    }, lines_of(bufnr))
  end)

  it("normalizes a leading-comma layout while still sorting", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    -- The comma sits at the start of the next line; the separator is still
    -- observed and render emits it in the usual trailing position.
    local bufnr = setup_buf({
      "{",
      '  "b": 2',
      '  ,"a": 1',
      "}",
    })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({
      "{",
      '  "a": 1,',
      '  "b": 2',
      "}",
    }, lines_of(bufnr))
  end)

  it("keeps a pair whose key is the empty string", function()
    if not has_json then
      return pending("JSON treesitter parser not available")
    end
    local bufnr = setup_buf({ '{ "b": 1, "": 2, "a": 3 }' })
    set_cursor(0, 0)
    vim.cmd("SortKeys")
    assert.are.same({ '{ "": 2, "a": 3, "b": 1 }' }, lines_of(bufnr))
  end)
end)
