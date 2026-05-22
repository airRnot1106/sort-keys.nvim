# sort-keys.nvim

[![CI](https://github.com/airRnot/sort-keys.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/airRnot/sort-keys.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Neovim plugin that sorts keys in structured data (JSON, Lua tables, etc.)
within the current buffer or a given range.

> Work in progress. The public API and configuration are still taking shape.

## Requirements

- Neovim 0.10 or newer

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "airRnot/sort-keys.nvim",
  cmd = { "SortKeys" },
  opts = {},
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "airRnot/sort-keys.nvim",
  config = function()
    require("sort-keys").setup({})
  end,
})
```

## Configuration

`setup` accepts a table of options that is merged on top of the defaults.

```lua
require("sort-keys").setup({
  -- options will be added as features land.
})
```

## Commands

| Command       | Description                                                      |
| ------------- | ---------------------------------------------------------------- |
| `:SortKeys`   | Sort keys in the current buffer or `[range]`.                    |

## Health

Run `:checkhealth sort-keys` to verify the plugin is loaded correctly.

## Development

```sh
# Run the test suite (clones plenary.nvim into /tmp on first run).
make test

# Format / lint.
make fmt        # apply stylua
make fmt-check  # verify stylua formatting
make lint       # selene
```

## License

[MIT](LICENSE) © airRnot
