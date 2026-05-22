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

### Nix

A `flake.nix` is provided for a reproducible toolchain (Neovim, stylua, selene,
make, git) and for packaging sort-keys.nvim itself as a derivation.

```sh
# Drop into a dev shell with the tools above on $PATH.
nix develop

# Launch Neovim with sort-keys.nvim installed via packpath
# (built from the current source tree as a real derivation — re-runs require a rebuild).
nix run

# Launch a Neovim that loads sort-keys.nvim from the current working directory.
# Useful while iterating on lua/ since edits show up without a rebuild.
nix run .#dev

# Build just the plugin derivation (placed under $out/share/vim-plugins/sort-keys.nvim).
nix build .#sort-keys-nvim
```

#### Consuming from another flake

`packages.sort-keys-nvim` is exposed so downstream flakes can pick up the
plugin without going through nixpkgs:

```nix
{
  inputs.sort-keys.url = "github:airRnot/sort-keys.nvim";

  outputs = { self, nixpkgs, sort-keys }: {
    # then add sort-keys.packages.${system}.sort-keys-nvim to your
    # wrapNeovim / home-manager / NixOS plugins list.
  };
}
```

## License

[MIT](LICENSE) © airRnot
