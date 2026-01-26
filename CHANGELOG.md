# Changelog

## [v0.2.0] - 2026-01-26
### :sparkles: New Features
- [`2859c6c`](https://github.com/airRnot1106/sort-keys.nvim/commit/2859c6c8000963a3f23e87bfd7027cab7e805352) - add Nix language support with context-aware separators *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`d5e9676`](https://github.com/airRnot1106/sort-keys.nvim/commit/d5e9676a4fef301022937afff0b77bda4f8c23b3) - add foundation modules *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`50830c6`](https://github.com/airRnot1106/sort-keys.nvim/commit/50830c6a6038fe677f22c324e5160f550b3c811a) - add core sorting logic *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`14d0730`](https://github.com/airRnot1106/sort-keys.nvim/commit/14d07303e8cd85f367a572764006da299e30d39f) - add JSON adapter *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`142c920`](https://github.com/airRnot1106/sort-keys.nvim/commit/142c9203d9d29d7cf92d0edbf4f1ef814ee9974f) - add Lua adapter *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`fd1b6a9`](https://github.com/airRnot1106/sort-keys.nvim/commit/fd1b6a9f88ccabb3077162b66c272eb9562735b1) - add JavaScript/TypeScript adapter *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`c8f57e1`](https://github.com/airRnot1106/sort-keys.nvim/commit/c8f57e15fe59a09e733f87504c1cfbd9b165402a) - add Nix adapter *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`3ca4ed7`](https://github.com/airRnot1106/sort-keys.nvim/commit/3ca4ed7e5fad4ad9863b3dd73d1b29f17786d154) - add public API and command registration *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`f4fbb37`](https://github.com/airRnot1106/sort-keys.nvim/commit/f4fbb37e6a3a7d06114847a1cbfcb323b73b650a) - allow overriding existing adapters *(commit by [@airRnot1106](https://github.com/airRnot1106))*

### :bug: Bug Fixes
- [`75c4c2c`](https://github.com/airRnot1106/sort-keys.nvim/commit/75c4c2c56c75acc06e574d4f02884ec48b52d5fa) - range selection and trailing separator handling *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`e7483af`](https://github.com/airRnot1106/sort-keys.nvim/commit/e7483af16aed9621cf62199bcccf97672d7ffe74) - improve trailing separator detection for Nix *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`bb998ce`](https://github.com/airRnot1106/sort-keys.nvim/commit/bb998ce3f40f27095ce55543fda64c0334f24fee) - DeepSortKeys single-line container handling *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`ac94295`](https://github.com/airRnot1106/sort-keys.nvim/commit/ac942956855e4d7160104e4005112d16a82e6a7f) - range selection finds innermost container *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`49b1e42`](https://github.com/airRnot1106/sort-keys.nvim/commit/49b1e4255bde7238076561099e58fa5a7a800410) - numeric sort treats keys without numbers as 0 *(commit by [@airRnot1106](https://github.com/airRnot1106))*

### :recycle: Refactors
- [`d1b970f`](https://github.com/airRnot1106/sort-keys.nvim/commit/d1b970f205fc0f864df7193c1bcd44f0fd09b147) - move filetype definitions to adapters *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`741932c`](https://github.com/airRnot1106/sort-keys.nvim/commit/741932c756ed027fff1e0603dec57373f548c5ab) - simplify SortKeysConfig to only expose custom_adapters *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`62e0d8c`](https://github.com/airRnot1106/sort-keys.nvim/commit/62e0d8ce03a602fd7eca0e85518266a3bc700562) - remove M.deep_sort_keys from public API, handle deep check optionally *(commit by [@airRnot1106](https://github.com/airRnot1106))*

### :wrench: Chores
- [`85ff963`](https://github.com/airRnot1106/sort-keys.nvim/commit/85ff963e8dbc9e8f81cd9a7db6bc76d589d3fc28) - destroy everything *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`3bc0812`](https://github.com/airRnot1106/sort-keys.nvim/commit/3bc0812ba41f0fc6a5ad6a60d9de80e3153a5b36) - add flake.nix *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`ac9c672`](https://github.com/airRnot1106/sort-keys.nvim/commit/ac9c6729a41e67a976693681786b2cb5ad59b447) - add selene.toml *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`4137bae`](https://github.com/airRnot1106/sort-keys.nvim/commit/4137baebb13dda0f098568ab9ee350b293d0be90) - add .stylua.toml *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`6452f0e`](https://github.com/airRnot1106/sort-keys.nvim/commit/6452f0e05f285b93807f0391936b421d8cc0fb1c) - add release workflow *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`9b58ef5`](https://github.com/airRnot1106/sort-keys.nvim/commit/9b58ef5a8800e83fe5f9e5158e2c819145dcf66a) - enable dependabot *(commit by [@airRnot1106](https://github.com/airRnot1106))*
- [`cb9a1ce`](https://github.com/airRnot1106/sort-keys.nvim/commit/cb9a1ce351492d275c7588fc1ff71844f3c3509c) - release v0.2.0 *(commit by [@airRnot1106](https://github.com/airRnot1106))*


## [v0.1.0] - 2026-01-24

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
[v0.2.0]: https://github.com/airRnot1106/sort-keys.nvim/compare/v0.1.0...v0.2.0
