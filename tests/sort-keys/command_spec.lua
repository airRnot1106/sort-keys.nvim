-- command.run isolates extract-stage failures so a buggy (e.g. third-party)
-- extractor surfaces as a notification instead of an uncaught error.

describe("command extract isolation", function()
  local notifies
  local original_notify

  before_each(function()
    require("sort-keys.config").setup({})
    vim.g.loaded_sort_keys = nil
    vim.cmd("runtime plugin/sort-keys.lua")
    notifies = {}
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifies, { msg = msg, level = level })
    end
  end)

  after_each(function()
    vim.notify = original_notify
    require("sort-keys.config").setup({})
  end)

  it("reports a throwing custom extractor instead of raising", function()
    require("sort-keys.config").setup({
      handlers = {
        boom = {
          filetypes = { "boomft" },
          options = {},
          query_text = "",
          extractor = {
            extract = function()
              error("kaboom")
            end,
          },
        },
      },
    })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "{}" })
    vim.bo[bufnr].filetype = "boomft"
    vim.api.nvim_set_current_buf(bufnr)

    -- Must not raise out of the command.
    assert.has_no.errors(function()
      vim.cmd("SortKeys")
    end)

    local saw_error = false
    for _, n in ipairs(notifies) do
      if n.level == vim.log.levels.ERROR and n.msg:match("extract failed") then
        saw_error = true
      end
    end
    assert.is_true(saw_error)
  end)
end)
