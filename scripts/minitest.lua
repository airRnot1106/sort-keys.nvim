#!/usr/bin/env -S nvim -l

-- Test runner script for mini.test
-- Usage: nvim --headless -l scripts/minitest.lua

-- Add current directory to runtimepath
vim.opt.rtp:prepend "."

-- Add mini.nvim to runtimepath (for mini.test)
local mini_path = vim.fn.stdpath "data" .. "/site/pack/deps/start/mini.nvim"
if vim.fn.isdirectory(mini_path) == 0 then
    vim.fn.system { "git", "clone", "--depth=1", "https://github.com/echasnovski/mini.nvim", mini_path }
end
vim.opt.rtp:prepend(mini_path)

-- Set up mini.test
local MiniTest = require "mini.test"
MiniTest.setup()

-- Run tests
local test_dir = "tests"
if vim.fn.isdirectory(test_dir) == 1 then
    MiniTest.run {
        collect = {
            find_files = function()
                return vim.fn.globpath(test_dir, "**/*_spec.lua", true, true)
            end,
        },
        execute = {
            reporter = MiniTest.gen_reporter.stdout { group_depth = 2 },
        },
    }
else
    print("Test directory not found: " .. test_dir)
    vim.cmd "cquit 1"
end
