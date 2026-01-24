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
    default_options = {
        reverse = false,        -- Sort in reverse order (Z-A)
        deep = false,           -- Recursively sort nested objects
        case_sensitive = true,  -- Case-sensitive sorting
        natural_sort = false,   -- Natural number sorting
    },
    custom_adapters = {},       -- Custom language adapters
})
```

## Commands

| Command                 | Description                                       |
| ----------------------- | ------------------------------------------------- |
| `:SortKeys [flags]`     | Sort object keys at cursor position               |
| `:SortKeys!`            | Sort in reverse order                             |
| `:DeepSortKeys [flags]` | Recursively sort all nested objects               |
| `:[range]SortKeys`      | Sort only entries within the specified line range |

### Flags

- `i` - Case-insensitive sorting
- `n` - Natural number sorting

**Examples:**

```vim
:SortKeys          " Sort alphabetically
:SortKeys!         " Sort in reverse (Z-A)
:SortKeys i        " Case-insensitive
:SortKeys in       " Case-insensitive + natural sort
:10,20SortKeys     " Sort only lines 10-20
:DeepSortKeys      " Sort recursively
```

## API

```lua
-- Sort keys at cursor position
require("sort-keys").sort_keys({
    reverse = false,
    deep = false,
    case_sensitive = true,
    natural_sort = false,
})

-- Register a custom adapter
require("sort-keys").register_adapter(adapter)

-- Get list of supported filetypes
require("sort-keys").get_supported_filetypes()
```

## Usage Examples

### JSON

```json
// Before
{
  "zebra": 1,
  "apple": 2,
  "banana": 3
}

// After :SortKeys
{
  "apple": 2,
  "banana": 3,
  "zebra": 1
}
```

### JavaScript/TypeScript

```javascript
// Before
const config = {
  zebra: 1,
  apple: 2,
  banana: 3,
};

// After :SortKeys
const config = {
  apple: 2,
  banana: 3,
  zebra: 1,
};
```

### Lua

```lua
-- Before
local config = {
    zebra = 1,
    apple = 2,
    banana = 3,
}

-- After :SortKeys
local config = {
    apple = 2,
    banana = 3,
    zebra = 1,
}
```

## Custom Adapters

You can register custom adapters for additional languages:

```lua
local base = require("sort-keys.adapters.base")

require("sort-keys").setup({
    custom_adapters = {
        base.create({
            name = "yaml",
            filetypes = { "yaml", "yml" },
            get_sortable_node_types = function()
                return { "block_mapping" }
            end,
            get_entry_node_type = function()
                return "block_mapping_pair"
            end,
            extract_key = function(node, source)
                local key_node = node:named_child(0)
                if key_node then
                    return vim.treesitter.get_node_text(key_node, source)
                end
                return nil
            end,
        }),
    },
})
```

### Adapter Interface

| Field/Method                | Required | Description                        |
| --------------------------- | -------- | ---------------------------------- |
| `name`                      | Yes      | Adapter name                       |
| `filetypes`                 | Yes      | Supported filetypes                |
| `get_sortable_node_types()` | Yes      | Returns sortable object node types |
| `get_entry_node_type()`     | Yes      | Returns entry node type(s)         |
| `extract_key(node, source)` | Yes      | Extracts key string from entry     |
| `is_sortable_entry(node)`   | No       | Checks if node is sortable entry   |
| `get_separator()`           | No       | Returns separator (default: `,`)   |
| `get_comment_node_types()`  | No       | Returns comment node types         |

## License

MIT
