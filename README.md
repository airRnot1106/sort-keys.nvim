<div align="center">
<samp>

# sort-keys.nvim

Sort object/table keys using tree-sitter, similar to the built-in sort command

</samp>
</div>

## Demo

![Demo](https://github.com/user-attachments/assets/3d104db3-625d-43f7-8986-63a52a5bf499)

## Features

- 🔤 **Alphabetical sorting** - Sort keys A-Z or Z-A
- 🔄 **Deep sorting** - Recursively sort nested objects
- 💬 **Comment preservation** - Keep comments attached to their entries
- 🔢 **Natural sort** - Sort `item1, item2, item10` correctly
- 📝 **Case-insensitive** - Optional case-insensitive sorting
- 📏 **Partial sorting** - Sort only selected lines within an object
- 🔌 **Extensible** - Register custom adapters for additional languages

## Supported Languages

See [Adapters](https://github.com/airRnot1106/sort-keys.nvim/tree/main/lua/sort-keys/adapters) for the list of supported languages.

## Requirements

- Neovim >= 0.9.0
- Treesitter parsers for target languages

## Installation

### lazy.nvim

```lua
{
    "airRnot1106/sort-keys.nvim",
    config = function()
        require("sort-keys").setup()
    end,
}
```

### packer.nvim

```lua
use {
    "airRnot1106/sort-keys.nvim",
    config = function()
        require("sort-keys").setup()
    end,
}
```

### vim-plug

```vim
Plug 'airRnot1106/sort-keys.nvim'
```

```lua
-- In your init.lua
require("sort-keys").setup()
```

## Configuration

```lua
require("sort-keys").setup({
    -- Register custom adapters
    custom_adapters = {
        -- Override or add language adapters
    },
})
```

## Usage

### Commands

```vim
:[range]SortKeys[!] [flags]
:[range]DeepSortKeys[!] [flags]
```

| Command | Description |
|---------|-------------|
| `:SortKeys` | Sort keys in container at cursor |
| `:DeepSortKeys` | Recursively sort nested containers |
| `:'<,'>SortKeys` | Sort keys within selected range |
| `:SortKeys!` | Sort in reverse order |

### Flags

| Flag | Description |
|------|-------------|
| `i` | Case-insensitive |
| `n` | Numeric (decimal) |
| `f` | Numeric (float) |
| `x` | Numeric (hexadecimal) |
| `o` | Numeric (octal) |
| `b` | Numeric (binary) |
| `u` | Unique (remove duplicates) |

Flags can be combined: `:SortKeys in` (case-insensitive numeric sort)

### APIs

```lua
local sort_keys = require("sort-keys")

-- Sort keys at cursor position
sort_keys.sort_keys({
    flags = "i",      -- Optional: sort flags
    reverse = false,  -- Optional: reverse sort order
    deep = false,     -- Optional: recursively sort nested containers
    range = nil,      -- Optional: { start_line, end_line } (1-indexed)
})

-- Register a custom adapter at runtime
sort_keys.register_adapter("mylang", my_adapter)

-- Get list of supported languages
sort_keys.get_supported_languages()
```

### Custom Adapters

```lua
local base = require("sort-keys.adapters.base")

local my_adapter = base.create({
    filetypes = { "mylang" },
    container_types = { "object", "array" },
    element_wrappers = {},  -- Intermediate nodes (e.g., Nix's binding_set)
    element_types = {
        object = "pair",
        array = nil,  -- nil means direct children
    },
    separators = {
        object = ",",
        array = ",",
    },
    exclude_types = { "spread_element" },  -- Elements to keep in place
    get_key_from_element = function(element, bufnr)
        local key_node = element:field("key")[1]
        if key_node then
            return vim.treesitter.get_node_text(key_node, bufnr)
        end
        return vim.treesitter.get_node_text(element, bufnr)
    end,
})

require("sort-keys").setup({
    custom_adapters = {
        mylang = my_adapter,
    },
})
```

#### Adapter Interface

| Field | Type | Description |
|-------|------|-------------|
| `filetypes` | `string[]` | Filetypes this adapter handles |
| `container_types` | `string[]` | Tree-sitter node types that can be sorted |
| `element_wrappers` | `table<string, string>` | Container type → wrapper node type mapping |
| `element_types` | `table<string, string\|nil>` | Container type → element node type mapping |
| `separators` | `table<string, string>` | Container type → separator character mapping |
| `exclude_types` | `string[]` | Node types to exclude from sorting |
| `get_key_from_element` | `function(node, bufnr): string\|nil` | Extract sort key from element |

## LICENSE

MIT
