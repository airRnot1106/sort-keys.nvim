-- Custom test runner for sort-keys.nvim
-- Usage: nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua dofile('scripts/minitest.lua')"

-- Run tests with custom file pattern (*_spec.lua instead of test_*.lua)
MiniTest.run {
    collect = {
        find_files = function()
            return vim.fn.globpath("tests", "**/*_spec.lua", true, true)
        end,
    },
}
