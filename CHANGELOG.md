# Changelog

## [0.4.0](https://github.com/airRnot1106/sort-keys.nvim/compare/v0.3.0...v0.4.0) (2026-06-04)


### Features

* **filetype:** add Elixir support ([d5630e7](https://github.com/airRnot1106/sort-keys.nvim/commit/d5630e7e68ee233077f5b3518ed5b51b50cd0b8f))
* **filetype:** add Gleam support ([a4fa0fc](https://github.com/airRnot1106/sort-keys.nvim/commit/a4fa0fc70f51f374f14398c3e7a95834f35d7831))
* **filetype:** add Go support ([001a232](https://github.com/airRnot1106/sort-keys.nvim/commit/001a2329b110126c1530e8a716e393159f8b72a4))
* **filetype:** add KDL support ([a70338e](https://github.com/airRnot1106/sort-keys.nvim/commit/a70338e37af978b8b0140d2d1ab9abeeec913f6e))
* **filetype:** add Pkl support ([d89a472](https://github.com/airRnot1106/sort-keys.nvim/commit/d89a47237866cf0d03ee0f41bd831a571c3dff76))
* **filetype:** add Python support ([6da8c8c](https://github.com/airRnot1106/sort-keys.nvim/commit/6da8c8c15aa1e3da64a2b0264f1933c1a8a2c360))
* **filetype:** add Ruby support ([de51040](https://github.com/airRnot1106/sort-keys.nvim/commit/de510408f8c4e69b4080729fcd748c6159ca08a0))
* **filetype:** add Rust support ([e430b0d](https://github.com/airRnot1106/sort-keys.nvim/commit/e430b0d65e713715ef7636b21aef43feae8cba7d))


### Bug Fixes

* **core:** close remaining sort crash paths (regex flag, over-range code points) ([9c5bbc5](https://github.com/airRnot1106/sort-keys.nvim/commit/9c5bbc56ffacfdbb9fa6873ff1695eeb256011c3))
* **core:** forward data_range through apply_selection_overlay ([130726f](https://github.com/airRnot1106/sort-keys.nvim/commit/130726f279b12e85ea9971c79ea9e9a6513863f4))
* **core:** honor the u flag's deduplication through the applier ([face696](https://github.com/airRnot1106/sort-keys.nvim/commit/face696f3e4bc7edf48121d361b2e1c3e8940125))
* **core:** place inter-entry separator across absorbed trailing comments ([4fb60fc](https://github.com/airRnot1106/sort-keys.nvim/commit/4fb60fc844e606f7927d20df181b7ac2a924f156))
* **core:** stop dropping duplicate-keyed and multi-match entries ([48953f0](https://github.com/airRnot1106/sort-keys.nvim/commit/48953f0d39e469b71080e6aac4f75d1f3b431121))
* **handlers:** drop comment-captured nodes from sortable entries ([9a0df6d](https://github.com/airRnot1106/sort-keys.nvim/commit/9a0df6d5b35470a113014bb975b5df0000bf6411))
* **javascript:** decode JS key escapes leniently so non-JSON escapes can't crash sorting ([c1e6fe2](https://github.com/airRnot1106/sort-keys.nvim/commit/c1e6fe28911fba7ccf685ab92dab08654c71cb2d))
* **key_escapes:** decode key escapes leniently so no language can crash sorting ([b54ffb5](https://github.com/airRnot1106/sort-keys.nvim/commit/b54ffb57e460d2f6010cd0b77585d7001a63485e))
* **policy:** fence order-sensitive pins so sorting can't cross them ([f65a7df](https://github.com/airRnot1106/sort-keys.nvim/commit/f65a7df5de064d1023883a6a335732febd50f7ae))
* **registry:** isolate builder options from the shared built-in cache ([47fadbc](https://github.com/airRnot1106/sort-keys.nvim/commit/47fadbca4db3ac7c511efe54703005811c62fb9b))
* **toml:** tolerate inline comments after scalar values ([5d43c17](https://github.com/airRnot1106/sort-keys.nvim/commit/5d43c178e954b2a021362ed4c028d52b031ff817))


### Performance Improvements

* **registry:** memoize built-in spec disk reads ([e927845](https://github.com/airRnot1106/sort-keys.nvim/commit/e927845548ef811eda2c0b6bd87c03db10b3579c))


### Documentation

* **claude:** align architecture and builder guide with current code ([afac295](https://github.com/airRnot1106/sort-keys.nvim/commit/afac2958dcac7ae0dcb6e649b4463a05be6f1641))
* **comments:** strip historical narrative from WHY comments ([98b93f0](https://github.com/airRnot1106/sort-keys.nvim/commit/98b93f0c5bd1ad9012e4562615b64f5395267fdc))
* **vimdoc:** align builder reference with the shared-helpers layout ([ef84f8e](https://github.com/airRnot1106/sort-keys.nvim/commit/ef84f8e8ff21772e81b7635c2e6fde72c0137433))

## [0.3.0](https://github.com/airRnot1106/sort-keys.nvim/compare/v0.2.3...v0.3.0) (2026-05-25)


### Features

* **command:** wire :SortKeys and :DeepSortKeys to the sort engine ([7116aa8](https://github.com/airRnot1106/sort-keys.nvim/commit/7116aa8b9c7328f5a19e20dda45c7b81c95d92fe))
* **config:** add normalize_keys and comparator options ([a609440](https://github.com/airRnot1106/sort-keys.nvim/commit/a609440b1004d59ea8a1888ab3ce70918badd043))
* **config:** register user handlers via setup({handlers={...}}) ([3fb8e98](https://github.com/airRnot1106/sort-keys.nvim/commit/3fb8e982aa823002a36108ca6c0e995b95282aa4))
* **core:** add comment-aware outline policies and wire them through ([61e7d5b](https://github.com/airRnot1106/sort-keys.nvim/commit/61e7d5b1d85657d7a54b34e665cdcef84d049832))
* **core:** add sort engine primitives ([4c66f7b](https://github.com/airRnot1106/sort-keys.nvim/commit/4c66f7b3a300ed38e9e107472522eefec5685490))
* **filetype:** add JavaScript support ([4b1a572](https://github.com/airRnot1106/sort-keys.nvim/commit/4b1a5721b5111b58c008eae38a089007dc9494fc))
* **filetype:** add JSONC support ([ba2236b](https://github.com/airRnot1106/sort-keys.nvim/commit/ba2236b93e1c8c439ca9f6dd55a9c740e8b201c7))
* **filetype:** add Lua support ([4b7119e](https://github.com/airRnot1106/sort-keys.nvim/commit/4b7119eddc3319fac31d98691398fe89717add76))
* **filetype:** add Nix support ([d5e5ed5](https://github.com/airRnot1106/sort-keys.nvim/commit/d5e5ed5ea1fbe2ed82391f84798f20bf1e43c01f))
* **filetype:** add TOML support ([7d1f303](https://github.com/airRnot1106/sort-keys.nvim/commit/7d1f3033f661afc5e769c03487c07923d8c9bf9e))
* **filetype:** add TypeScript support ([d222a94](https://github.com/airRnot1106/sort-keys.nvim/commit/d222a94c20dd6d08641d145c68c41e88cba3a787))
* **filetype:** add YAML support ([25180e1](https://github.com/airRnot1106/sort-keys.nvim/commit/25180e172c087d2ba03e0afd5a9588d3c2b0d6aa))
* **handlers:** add JSON declarative handler and filetype registry ([c0425cd](https://github.com/airRnot1106/sort-keys.nvim/commit/c0425cd65736560c13a40200074afc1b7dcb24a8))
* **nix:** add flake.nix and development shell setup ([0fe624e](https://github.com/airRnot1106/sort-keys.nvim/commit/0fe624ee804d2480f6a532cd5ad9b1cb7418440d))


### Bug Fixes

* **comment_attach:** select comment targets using original entry ranges ([53237ff](https://github.com/airRnot1106/sort-keys.nvim/commit/53237ffeda354a4a5452cb3a66cbc859bed0e5ee))
* **tests/support:** require parser binary on runtimepath in has_parser ([55798af](https://github.com/airRnot1106/sort-keys.nvim/commit/55798afa21311ee9f7f80f9e91f78764ee1c7b65))


### Documentation

* **claude:** rewrite CLAUDE.md to match the current architecture ([01f9832](https://github.com/airRnot1106/sort-keys.nvim/commit/01f983245a62ec4d63df94d43cdce351440fc646))
* migrate reference docs to vimdoc and simplify README ([c94e8b7](https://github.com/airRnot1106/sort-keys.nvim/commit/c94e8b70c98760ad98b060f793050f6b790e4e35))

## [v0.2.3] - 2026-02-03

### :sparkles: New Features

- [`5d62e6b`](https://github.com/airRnot1106/sort-keys.nvim/commit/5d62e6baa493859ad56b4cfb7894a4cb70f2a2f4) - **toml**: add TOML adapter support _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :bug: Bug Fixes

- [`6e2db8e`](https://github.com/airRnot1106/sort-keys.nvim/commit/6e2db8e3fb6adca3b0d0cc463b89a04cfce18fd0) - **nix**: use full attrpath for sorting dotted keys _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :wrench: Chores

- [`beb4ec2`](https://github.com/airRnot1106/sort-keys.nvim/commit/beb4ec22fcc36794c4311ee5949784aa5607b66f) - release v0.2.3 _(commit by [@airRnot1106](https://github.com/airRnot1106))_

## [v0.2.2] - 2026-01-27

### :sparkles: New Features

- [`96af609`](https://github.com/airRnot1106/sort-keys.nvim/commit/96af609648845f58109e674bc4bd025c6159513b) - **adapters**: add brackets configuration for container types _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`5e6cae8`](https://github.com/airRnot1106/sort-keys.nvim/commit/5e6cae8808c285048d56594c7f8924dc24a3243c) - **yaml**: add YAML adapter support _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :bug: Bug Fixes

- [`254b9c8`](https://github.com/airRnot1106/sort-keys.nvim/commit/254b9c8d9b3965bd0302fbb68714217b8fcb74a5) - **deep-sort**: re-parse tree-sitter after each container sort _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :wrench: Chores

- [`9f77c4e`](https://github.com/airRnot1106/sort-keys.nvim/commit/9f77c4e8ec59f16c96a7a4b22b94dfb9caebc42d) - add luarc config and update type definitions _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`d5c6122`](https://github.com/airRnot1106/sort-keys.nvim/commit/d5c612258049fb0c3b73b02a1a656f2559bd1d6b) - release v0.2.2 _(commit by [@airRnot1106](https://github.com/airRnot1106))_

## [v0.2.1] - 2026-01-27

### :sparkles: New Features

- [`a4be696`](https://github.com/airRnot1106/sort-keys.nvim/commit/a4be69687fec6e78842ea24f11ac0d81e3160ea9) - add TypeScript adapter with type-specific container support _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`3246714`](https://github.com/airRnot1106/sort-keys.nvim/commit/3246714eb56854a80bfaabd00769b60b369f6ca8) - preserve trailing comments on the same line _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`862a41f`](https://github.com/airRnot1106/sort-keys.nvim/commit/862a41f991d4f066db170883d9ae37b5eea60415) - **javascript**: add object*pattern and rest_pattern support *(commit by [@airRnot1106](https://github.com/airRnot1106))\_

### :bug: Bug Fixes

- [`bd0ca0c`](https://github.com/airRnot1106/sort-keys.nvim/commit/bd0ca0ce7dfd45d304407ca57f63658614b0faef) - typo _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`3eb895d`](https://github.com/airRnot1106/sort-keys.nvim/commit/3eb895d25ddab1a0278927c0e4823f5271b1f800) - correct bracket detection and skip comments in element extraction _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`4d13e8b`](https://github.com/airRnot1106/sort-keys.nvim/commit/4d13e8b76b527bb596bb310a881dcf0e0b622a7c) - wrap gsub return values to return single value _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`8c0d53d`](https://github.com/airRnot1106/sort-keys.nvim/commit/8c0d53d84ea67619d739aa859d7abcda35d38556) - **ci**: install tree-sitter parsers in test runner script _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :recycle: Refactors

- [`103947c`](https://github.com/airRnot1106/sort-keys.nvim/commit/103947cfcf1f92c6a81525d5a75242e963901dcb) - use filetype instead of tree-sitter language for adapter lookup _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`1a0c742`](https://github.com/airRnot1106/sort-keys.nvim/commit/1a0c7422ed94a4efd2669f152b6f7a7e44e6b6ee) - use ts*utils.get_node_text in all adapters *(commit by [@airRnot1106](https://github.com/airRnot1106))\_
- [`3be25d2`](https://github.com/airRnot1106/sort-keys.nvim/commit/3be25d276c3d8601e5cea08693d5e5b8bd6f81ae) - flatten tests directory structure _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`10c9a6c`](https://github.com/airRnot1106/sort-keys.nvim/commit/10c9a6c89c427da1c63abce25e7927c658f53245) - **test**: rebuild test infrastructure following mini.test best practices _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :white_check_mark: Tests

- [`68ff834`](https://github.com/airRnot1106/sort-keys.nvim/commit/68ff8347ce83af461e770b35f12fb71eca8ec87c) - add mini.test framework and CI workflow _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`0e2c0bf`](https://github.com/airRnot1106/sort-keys.nvim/commit/0e2c0bf505062310ded6a16279cff5eff98e6e62) - add integration tests for all language adapters _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`98ae596`](https://github.com/airRnot1106/sort-keys.nvim/commit/98ae596b1a07611fd65c21caf6241f209b7feb1d) - **nix**: add integration tests for Nix adapter _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :wrench: Chores

- [`4aed1c9`](https://github.com/airRnot1106/sort-keys.nvim/commit/4aed1c9599e250b481114e84da607a277820308c) - remove unit tests _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`94d82b2`](https://github.com/airRnot1106/sort-keys.nvim/commit/94d82b29bf7201f5449c1188bed37472d7f3d003) - release v0.2.1 _(commit by [@airRnot1106](https://github.com/airRnot1106))_

## [v0.2.0] - 2026-01-26

### :sparkles: New Features

- [`2859c6c`](https://github.com/airRnot1106/sort-keys.nvim/commit/2859c6c8000963a3f23e87bfd7027cab7e805352) - add Nix language support with context-aware separators _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`d5e9676`](https://github.com/airRnot1106/sort-keys.nvim/commit/d5e9676a4fef301022937afff0b77bda4f8c23b3) - add foundation modules _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`50830c6`](https://github.com/airRnot1106/sort-keys.nvim/commit/50830c6a6038fe677f22c324e5160f550b3c811a) - add core sorting logic _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`14d0730`](https://github.com/airRnot1106/sort-keys.nvim/commit/14d07303e8cd85f367a572764006da299e30d39f) - add JSON adapter _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`142c920`](https://github.com/airRnot1106/sort-keys.nvim/commit/142c9203d9d29d7cf92d0edbf4f1ef814ee9974f) - add Lua adapter _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`fd1b6a9`](https://github.com/airRnot1106/sort-keys.nvim/commit/fd1b6a9f88ccabb3077162b66c272eb9562735b1) - add JavaScript/TypeScript adapter _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`c8f57e1`](https://github.com/airRnot1106/sort-keys.nvim/commit/c8f57e15fe59a09e733f87504c1cfbd9b165402a) - add Nix adapter _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`3ca4ed7`](https://github.com/airRnot1106/sort-keys.nvim/commit/3ca4ed7e5fad4ad9863b3dd73d1b29f17786d154) - add public API and command registration _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`f4fbb37`](https://github.com/airRnot1106/sort-keys.nvim/commit/f4fbb37e6a3a7d06114847a1cbfcb323b73b650a) - allow overriding existing adapters _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :bug: Bug Fixes

- [`75c4c2c`](https://github.com/airRnot1106/sort-keys.nvim/commit/75c4c2c56c75acc06e574d4f02884ec48b52d5fa) - range selection and trailing separator handling _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`e7483af`](https://github.com/airRnot1106/sort-keys.nvim/commit/e7483af16aed9621cf62199bcccf97672d7ffe74) - improve trailing separator detection for Nix _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`bb998ce`](https://github.com/airRnot1106/sort-keys.nvim/commit/bb998ce3f40f27095ce55543fda64c0334f24fee) - DeepSortKeys single-line container handling _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`ac94295`](https://github.com/airRnot1106/sort-keys.nvim/commit/ac942956855e4d7160104e4005112d16a82e6a7f) - range selection finds innermost container _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`49b1e42`](https://github.com/airRnot1106/sort-keys.nvim/commit/49b1e4255bde7238076561099e58fa5a7a800410) - numeric sort treats keys without numbers as 0 _(commit by [@airRnot1106](https://github.com/airRnot1106))_

### :recycle: Refactors

- [`d1b970f`](https://github.com/airRnot1106/sort-keys.nvim/commit/d1b970f205fc0f864df7193c1bcd44f0fd09b147) - move filetype definitions to adapters _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`741932c`](https://github.com/airRnot1106/sort-keys.nvim/commit/741932c756ed027fff1e0603dec57373f548c5ab) - simplify SortKeysConfig to only expose custom*adapters *(commit by [@airRnot1106](https://github.com/airRnot1106))\_
- [`62e0d8c`](https://github.com/airRnot1106/sort-keys.nvim/commit/62e0d8ce03a602fd7eca0e85518266a3bc700562) - remove M.deep*sort_keys from public API, handle deep check optionally *(commit by [@airRnot1106](https://github.com/airRnot1106))\_

### :wrench: Chores

- [`85ff963`](https://github.com/airRnot1106/sort-keys.nvim/commit/85ff963e8dbc9e8f81cd9a7db6bc76d589d3fc28) - destroy everything _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`3bc0812`](https://github.com/airRnot1106/sort-keys.nvim/commit/3bc0812ba41f0fc6a5ad6a60d9de80e3153a5b36) - add flake.nix _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`ac9c672`](https://github.com/airRnot1106/sort-keys.nvim/commit/ac9c6729a41e67a976693681786b2cb5ad59b447) - add selene.toml _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`4137bae`](https://github.com/airRnot1106/sort-keys.nvim/commit/4137baebb13dda0f098568ab9ee350b293d0be90) - add .stylua.toml _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`6452f0e`](https://github.com/airRnot1106/sort-keys.nvim/commit/6452f0e05f285b93807f0391936b421d8cc0fb1c) - add release workflow _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`9b58ef5`](https://github.com/airRnot1106/sort-keys.nvim/commit/9b58ef5a8800e83fe5f9e5158e2c819145dcf66a) - enable dependabot _(commit by [@airRnot1106](https://github.com/airRnot1106))_
- [`cb9a1ce`](https://github.com/airRnot1106/sort-keys.nvim/commit/cb9a1ce351492d275c7588fc1ff71844f3c3509c) - release v0.2.0 _(commit by [@airRnot1106](https://github.com/airRnot1106))_

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
  [v0.2.1]: https://github.com/airRnot1106/sort-keys.nvim/compare/v0.2.0...v0.2.1
  [v0.2.2]: https://github.com/airRnot1106/sort-keys.nvim/compare/v0.2.1...v0.2.2
  [v0.2.3]: https://github.com/airRnot1106/sort-keys.nvim/compare/v0.2.2...v0.2.3
