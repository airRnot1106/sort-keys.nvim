# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

This project uses Nix flakes for development environment:

```bash
# Enter dev shell (provides selene, stylua, nixfmt)
nix develop

# Format code (stylua for Lua, nixfmt for Nix)
nix fmt

# Lint Lua code
selene lua/
```

Pre-commit hooks run selene and treefmt automatically on commit.

## Architecture

sort-keys.nvim is a Neovim plugin that sorts object/table/array keys using tree-sitter.

### Layer Structure

```
plugin/sort-keys.lua          → Command registration (:SortKeys, :DeepSortKeys)
       ↓
lua/sort-keys/init.lua        → Public API (setup, sort_keys, register_adapter)
       ↓
lua/sort-keys/core/
├── sorter.lua                → Main orchestrator (find containers, coordinate sorting)
├── parser.lua                → Flag parsing (i, n, f, x, o, b, u)
└── comparator.lua            → Comparison functions, exclusion handling
       ↓
lua/sort-keys/adapters/
├── init.lua                  → Registry (lazy loading, filetype mapping)
├── base.lua                  → Factory (generates AdapterInterface from config)
├── json.lua, lua.lua, etc.   → Language-specific configurations
       ↓
lua/sort-keys/utils/
├── treesitter.lua            → AST operations (find containers, get nodes)
└── text.lua                  → Text manipulation (indentation, separators)
```

### Adapter Pattern

Each language adapter is created via `base.create(config)` with:
- `filetypes`: Handled filetypes (e.g., `{"json", "jsonc", "json5"}`)
- `container_types`: AST node types to sort (e.g., `{"object", "array"}`)
- `element_wrappers`: Intermediate nodes between container and elements (e.g., Nix's `binding_set`)
- `element_types`: Child element types per container
- `separators`: Separator characters per container type
- `brackets`: Opening/closing bracket characters per container type (e.g., `{ "{", "}" }`)
- `exclude_types`: Elements to keep in place (e.g., spread operators)
- `get_key_from_element`: Language-specific key extraction function

The factory generates full `AdapterInterface` with `extract_elements()` and `format_output()` methods.

### Sorting Flow

1. Command handler parses flags and range
2. Sorter finds container(s) via tree-sitter
3. Adapter extracts elements with keys and comments
4. Comparator sorts (respecting exclusions and flags)
5. Adapter formats output preserving separators/indentation
6. Buffer updated with sorted text

### Key Design Decisions

- **Comments follow elements**: Associated via `prev_named_sibling()`
- **Excluded elements stay in place**: Spread operators, ellipses preserved
- **Deep sort is bottom-up**: Nested containers sorted deepest-first to preserve line numbers
- **Trailing separators preserved**: Original formatting maintained
