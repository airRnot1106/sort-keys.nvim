-- End-to-end check that a handler registered via setup({handlers={...}})
-- is actually reached by :SortKeys. Uses a fake builder so the test is
-- independent of any treesitter parser availability.

local function setup_buf(filetype, lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = filetype
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

local function lines_of(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

describe("user-registered handler end-to-end via :SortKeys", function()
  before_each(function()
    package.loaded["sort-keys"] = nil
    package.loaded["sort-keys.config"] = nil
    package.loaded["sort-keys.command"] = nil
    package.loaded["sort-keys.core.registry"] = nil
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
  end)

  it("routes :SortKeys for a user-registered filetype into the user builder", function()
    -- A builder that pretends the line `1 2 3 4` is a 4-element array and
    -- sorts ascending. The point isn't realistic parsing — it's that
    -- :SortKeys reached this code path with the expected config shape.
    local call_log = {}
    local fake_builder = {}
    function fake_builder.build(bufnr, target, config)
      call_log[#call_log + 1] = {
        filetype = config.filetype,
        query_text = config.query_text,
        options_can_sort_array = config.options.can_sort_array,
        target_kind = target.kind,
      }
      local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
      local entries = {}
      local col = 0
      for tok in line:gmatch("%S+") do
        local s = col
        local e = col + #tok
        entries[#entries + 1] = {
          kind = "element",
          sort_key = tok,
          range = { 0, s, 0, e },
          movable = true,
          anchor = #entries + 1,
          attached = {},
          child = nil,
        }
        col = e + 1
      end
      return {
        kind = "array",
        range = { 0, 0, 0, #line },
        structural_separator = " ",
        trailing_separator_allowed = false,
        entries = entries,
      }
    end

    require("sort-keys").setup({
      handlers = {
        fake_lang = {
          filetypes = { "fake_lang" },
          builder = fake_builder,
          options = {
            can_sort_object = false,
            can_sort_array = true,
            can_deep = false,
            key_quoting = "logical",
            comment_aware = false,
            structural_separator = " ",
            trailing_separator_allowed = false,
          },
          query_text = "FAKE_QUERY",
        },
      },
    })

    local bufnr = setup_buf("fake_lang", { "3 1 4 2" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("SortKeys")

    -- Builder was invoked through the public command path (not a direct
    -- registry.get call). The captured config carries the user-supplied
    -- query_text and options through unchanged.
    assert.equals(1, #call_log)
    assert.equals("fake_lang", call_log[1].filetype)
    assert.equals("FAKE_QUERY", call_log[1].query_text)
    assert.is_true(call_log[1].options_can_sort_array)
    assert.equals("cursor", call_log[1].target_kind)

    -- And the buffer text reflects the sort the fake builder + applier
    -- produced. This anchors the whole pipeline, not just the lookup.
    assert.equals("1 2 3 4", lines_of(bufnr)[1])
  end)
end)
