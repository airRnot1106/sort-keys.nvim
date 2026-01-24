# Changelog

## v0.1.0 (2025-01-24)

Initial release of sort-keys.nvim.

### Features

- **Alphabetical sorting** - Sort object/table keys A-Z or Z-A with `:SortKeys` command
- **Deep sorting** - Recursively sort nested objects with `:DeepSortKeys` command
- **Comment preservation** - Comments stay attached to their associated entries
- **Natural sort** - Sort `item1, item2, item10` in natural order with `n` flag
- **Case-insensitive sorting** - Ignore case when sorting with `i` flag
- **Reverse sorting** - Sort in reverse order with `!` (bang)
- **Partial sorting** - Sort only selected lines within an object using range (e.g., `:10,20SortKeys`)

### Supported Languages

- JSON / JSONC
- JavaScript / JSX
- TypeScript / TSX
- Lua

### Extensibility

- Custom adapter support for additional languages via `custom_adapters` option
- `register_adapter()` API for runtime adapter registration
