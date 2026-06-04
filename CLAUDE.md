# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
nix flake check                 # everything: tests + lint (selene) + format (stylua) + git-hooks
nix fmt                         # apply stylua formatting in place
nix run .#default               # launch wrapped nvim with sort-keys.nvim + all bundled tree-sitter parsers
nix run .#dev                   # launch nvim that loads sort-keys.nvim from cwd (live-edit dev launcher)
nix run .#vhs                   # regenerate vhs/demo.gif from vhs/demo.tape
```

Run a single spec file:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/sort-keys/core/comment_attach_spec.lua"
```

`plenary.nvim` is cloned to `/tmp/sort-keys.nvim/plenary.nvim` on first run, or supplied via `PLENARY_DIR` (Nix sets this to `pkgs.vimPlugins.plenary-nvim`). Tree-sitter parsers for all supported filetypes are bundled by the wrapped nvim used in `nix run`, so `:SortKeys` works out of the box without a user `~/.local/share/nvim/site/` install.

## Architecture: policy / detail separation

Two layers, hard-enforced by what each module is allowed to depend on.

### Data flow

```
:SortKeys / :DeepSortKeys / :'<,'>SortKeys
        │
        ▼
plugin/sort-keys.lua            user command registration (range, bang, nargs)
        │
        ▼
lua/sort-keys/command.lua       parses :sort-compat flags (!/i/n/r/u + /pat/),
        │                       builds a Target (cursor or selection range)
        ▼
lua/sort-keys/core/registry.lua filetype → { capabilities, outline } lookup.
        │                       built-in:  languages/<lang>/config.toml + languages/<lang>/sort-keys.scm (on disk)
        │                       user:      setup({handlers={...}}) injected at runtime
        ▼
lua/sort-keys/languages/        runs the per-language treesitter query, collects
  <lang>/builder.lua            entries + comments, normalizes each sort_key via
        │                       languages/<lang>/key_normalize, optionally delegates
        │                       comment attachment to core/comment_attach.
        ▼ Outline
core/walker.lua                 :DeepSortKeys → post-order recursion into entry.child
        │                       before sorting the parent. :SortKeys = shallow.
        ▼
core/policy.lua                 stable sort + :sort-compat flag pipeline + anchor-aware
        │                       movable slots. For visual targets, apply_selection_overlay
        │                       flips entries outside the selection to movable=false first.
        ▼
core/applier.lua                rebuilds the buffer text from the sorted Outline.
        │                       When outline.structural_separator is set, delegates
        │                       inter-entry separator emission to core/separator_normalize.
        ▼
nvim_buf_set_text               buffer write-back
```

### Dependency direction (read this if the arrows above looked one-way)

The arrows in the data flow show **runtime control + data**. The `require`
graph points the opposite way: every policy-layer module is leaf-like and
ignorant of its callers — it only knows the shapes it operates on
(Outline tables, piece/gap arrays, key text). Detail-layer modules pull
policy in:

```
high-level detail        →  require              ←  low-level pure policy
─────────────────────────                          ─────────────────────────
command.lua              ──require──────────►   core/{target,policy,walker,applier}, registry, config
core/registry.lua        ──require──────────►   core/toml_loader, languages/<lang>/builder × N
core/applier.lua         ──require──────────►   core/separator_normalize
core/walker.lua          ──require──────────►   core/policy, core/entry
core/policy.lua          ──require──────────►   core/unicode, core/entry
core/comment_attach.lua  ──require──────────►   core/entry
core/builder_helpers.lua ──require──────────►   core/container_pick
languages/<lang>/builder ──require──────────►   core/builder_helpers, core/comment_attach,
                                                  languages/<lang>/key_normalize
languages/<lang>/key_normalize ─require────►    core/key_escapes (shared escape decoders)

(no incoming requires)                          core/{comment_attach, separator_normalize,
                                                     container_pick, unicode, entry, key_escapes}
```

So `comment_attach` / `separator_normalize` / `container_pick` / `policy`
never reach up to a builder or to `vim.*`; the builder reaches down to
them through the shared Outline abstraction. **This is the dependency
inversion that makes the policy test suite pure-Lua**: a spec can
`require("sort-keys.core.policy")` and feed it a literal Outline without
spinning up nvim or treesitter.

Two known places where the inversion is only partial:

- `registry.lua` `require`s each built-in builder module directly.
  Self-registration via `builder.M.filetypes` keeps filetype→builder
  mapping out of `registry`, but the builder list itself is still
  hardcoded. (User handlers escape this via `setup({handlers={...}})`.)
- `command.lua` `require`s `registry` directly; the dispatch glue and
  the lookup layer are at the same abstraction level here, so no
  inversion is meaningful.

### Policy layer (pure Lua, no `vim.*` / no treesitter / no buffer)

The language-agnostic engine lives in `lua/sort-keys/core/` and operates entirely on Outline literals and plain Lua tables. (The one policy concern that is genuinely per-language — key normalization — is colocated with each builder at `languages/<lang>/key_normalize.lua`: still pure Lua, still nvim-free to test, but organized feature-first rather than under a separate policy directory. See "key normalization" below.) Each core file's job:

- `target.lua` — `cursor` / `selection` Target constructors.
- `policy.lua` — stable sort, anchor-aware movable slots, `:sort`-compat flags (`!`/`i`/`n`/`r/pat/`/`u`), custom `comparator`, `apply_selection_overlay` for Visual partial sort.
- `walker.lua` — post-order recursion for `:DeepSortKeys`; propagates `structural_separator` / `trailing_separator_allowed` into child copies.
- `comment_attach.lua` — assigns each comment to an entry by spatial relationship (leading attaches to the next entry, same-line trailing attaches to the previous) and expands the entry range to swallow it. **Walks the original entry ranges**, not the in-progress expanded ones, so back-to-back leading-comment blocks routing into different entries don't accidentally collapse onto the previous entry.
- `separator_normalize.lua` — inserts the inter-entry separator when missing and strips a trailing separator when the language forbids it. Treats `separator` as an opaque byte string, so whitespace separators (`"\n"` for YAML block style, `" "` for Nix lists / `inherited_attrs`) work the same as `,` / `;`.
- `container_pick.lua` — cursor → innermost container resolution with a 3-tier fallback (strict containment → same-row leftmost start → row-span innermost area), shared by builders.
- `entry.lua` — single forward-compatible Outline-entry copy helper (`copy(e, overrides?)` via `pairs`), used by every rebuild site (`comment_attach.copy_entry`, `policy.apply_selection_overlay`, `walker.rebuild_entry_with_child`) so a new Outline field is never silently dropped.
- `unicode.lua`, `toml_loader.lua` — pure helpers.
- `key_escapes.lua` — shared escape-decoding primitives (`unescape_json`, `utf8_encode`, `strip_double_quotes`) reused by the per-language key normalizers whose escape set overlaps JSON.

**Key normalization (pure, but colocated per-language):** each language's `languages/<lang>/key_normalize.lua` returns a pure `fun(text:string):string` that turns a raw key node's text into the canonical sort_key (quote stripping + per-language escape decoding). It lives next to that language's builder — feature-first — rather than under a shared policy directory; it stays pure (`require`s only `core/key_escapes`, never `vim.*`), so it is tested as pure policy. A builder `require`s its sibling normalizer once to declare its `M.key_normalizer` default, but `build` consumes the injected `config.key_normalizer` (dependency injection), so it is never coupled to a concrete normalizer and a user can override it via the handler spec.

### Detail layer (treesitter / buffer / runtime lookup)

- `lua/sort-keys/languages/<lang>/builder.lua` — runs the per-language treesitter query and returns an Outline. Each builder self-declares `M.filetypes = { <ft> = <config_name>, ... }` so the registry doesn't hardcode filetype → builder mapping.
- `lua/sort-keys/core/builder_helpers.lua` — the shared treesitter-aware scaffolding every builder calls: `node_range` / `node_id_key` / `first_child_of_type` / `find_inner_container_within` (deep-recursion: the value/pattern subtree itself or one level down) / `pos_inside` / `contains_range` / `range_area` / `pick_innermost` (O(n) selection min-pass) / `collect_matches` (returns `containers, entries, comments, containers_by_key` in one pass) / `index_by_parent` / `normalize_element_text` / `clamp_range_to_buffer` / `capability_allows` / `sort_entries_by_position` / `validate_options`. Builders import this as `local h = require("sort-keys.core.builder_helpers")`. Language-specific variations stay in the builder (YAML's overlap-based `pick_innermost`, Nix's `index_by_container_ancestor`, KDL / Lua / Pkl local `collect_matches` without kind metadata).
- `lua/sort-keys/core/applier.lua` — reads piece / gap text from the buffer, delegates inter-entry separator emission to `separator_normalize` when `outline.structural_separator` is set, writes back via `nvim_buf_set_text`.
- `lua/sort-keys/core/registry.lua` — built-in handlers come from `languages/<config_name>/config.toml` + `languages/<config_name>/sort-keys.scm` on `&runtimepath`. User handlers come from `set_user_handlers(specs)` (called from `config.setup`). Same-config-name overrides deep-merge over the built-in spec.
- `lua/sort-keys/command.lua` + `plugin/sort-keys.lua` — flag parsing and `:SortKeys` / `:DeepSortKeys` dispatch.

### Why this split

The policy modules are reusable across languages — all supported languages share the same `comment_attach` / `separator_normalize` / `policy.sort` / `walker`. The detail layer is what changes per language. Keeping the policy layer free of `vim.*` lets the bulk of the spec suite run as fast, deterministic unit tests on Outline literals — which is what makes the TDD Red step cheap enough to do honestly every time.

## Outline contract

The shape every builder returns and every consumer reads:

```lua
outline = {
  kind        = "object" | "array",
  range       = { srow, scol, erow, ecol },  -- 0-indexed, end-exclusive

  -- Opaque to policy / walker; consumed by applier + separator_normalize.
  structural_separator       = ",",          -- "" means "no inline separator" (whitespace-gapped)
  trailing_separator_allowed = true,

  entries = {
    {
      kind     = "pair" | "element",
      sort_key = "...",                       -- logical key after normalize
      range    = { srow, scol, erow, ecol },  -- may be expanded by comment_attach
      data_range = { srow, scol, erow, ecol }, -- set by comment_attach: the pre-absorb
                                              --   range, recording where the entry's
                                              --   data ends and an absorbed trailing
                                              --   comment begins. applier reads this to
                                              --   splice inter-entry separators BEFORE
                                              --   the comment.
      movable  = true,                        -- false = pinned at its anchor slot
      fence    = nil,                         -- true (only meaningful when movable=false)
                                              --   = an order-sensitive pin that BLOCKS
                                              --   crossing; movable entries sort only
                                              --   within the segment between fences. A
                                              --   plain pin (no fence) is permeable.
      anchor   = 1,                           -- 1-based source-order index; policy uses
                                              --   this to keep non-movable entries put
      attached = {},                          -- reserved
      child    = nil | outline,               -- nested container for :DeepSortKeys
    },
    -- ...
  },
}
```

`walker.recurse_children` and `policy.shallow_copy_outline` propagate `structural_separator` and `trailing_separator_allowed` through child copies. Drop those copies and the applier silently skips separator normalization at the affected level.

Every entry rebuild (overlay, deep-sort recursion, comment_attach copy) goes through `core/entry.copy`, which forwards all keys via `pairs` so additions like `data_range` survive without per-site enumeration.

`movable = false` entries stay at their `anchor` index after sorting; the movable entries fill the remaining slots in sort_key order. This is what powers (a) language-specific pins (Lua positional fields, JS spread, Nix `inherit`, `...` ellipses), (b) the visual-range overlay (entries outside the selection get `movable = false` so only the selected ones reorder).

A pin can additionally be a **fence** (`movable = false, fence = true`): movable entries sort only within the segment between fences and never cross one. Plain pins are permeable — movable entries may reorder across them — because their position relative to keyed entries is meaningless (Lua positional fields, Nix `inherit`). Fences are for _order-sensitive_ pins whose meaning depends on what sits before vs. after them: a JS spread / Ruby `**splat` (a later key overrides an earlier one) and JS computed keys. Builders set `fence = true` on exactly those entries; `policy.sort_with_anchors` honors it.

## Development workflow: TDD (t-wada style)

Drive every behavioral change through the Red → Green → Refactor cycle, and **anchor the cycle on the policy layer**, not on e2e:

1. **Red** — write a failing spec in `tests/sort-keys/core/*_spec.lua` (or, for a key normalizer, `tests/sort-keys/languages/key_normalize_spec.lua`) that expresses the new rule as an assertion on an Outline literal / pure-Lua input. The test name encodes the WHY of the rule. Run `nix flake check` and confirm it fails for the expected reason — not on a typo or a missing require.
2. **Green** — make it pass with the smallest possible change to a policy module (`core/*.lua` or a `languages/<lang>/key_normalize.lua`). Do not touch `vim.*`, treesitter, or the buffer to satisfy a policy test; if you feel the need to, the test is in the wrong layer.
3. **Refactor** — only with green tests. Policy modules must stay free of `vim.*` / treesitter / buffer dependencies, so refactoring is bounded by the layering rule above.

**Triangulate inside the policy layer**: prefer adding a second failing policy spec that forces the generalization over jumping straight to e2e. Detail and e2e specs (`languages/<lang>/builder_spec.lua`, `<lang>_e2e_spec.lua`) come **after** the policy is green, and only to pin the delegation contract or smoke-check the wiring — they are not where new behavior is designed.

If a policy spec doesn't feel like the right way to express the rule, the rule probably isn't a policy rule (= it belongs in a per-language builder, not in `core/`).

## Test policy

`tests/sort-keys/core/*_spec.lua` and `tests/sort-keys/languages/key_normalize_spec.lua` are the **emphasized layer** — they exercise pure policy on plain-Lua fixtures and should stay heavyweight (every rule of `comment_attach`, every separator edge case, every `:sort` flag, every key normalization escape, etc.). The key-normalizer spec loads each `languages/<lang>/key_normalize.lua` directly (no nvim), so colocating the normalizers with their builders does not move them out of the pure-policy test tier.

Detail and e2e tests are intentionally thinner:

- `tests/sort-keys/languages/<lang>/builder_spec.lua` pins the **delegation contract** ("when `options.comment_aware = true`, the entry range gets expanded by `comment_attach`"; "inherit binding is movable=false with a child container"), not every comment shape.
- `tests/sort-keys/<lang>_e2e_spec.lua` is a smoke check that the wired pipeline still produces correct buffer text after reorder.
- `tests/sort-keys/user_handler_e2e_spec.lua` exercises the public `setup({handlers={...}})` path end-to-end with a fake builder, so the test is independent of any treesitter parser availability.
- `tests/sort-keys/{config,command,init}_spec.lua` pin entry-point shape and the config defaults.
- `tests/support/treesitter.lua` exposes `has_parser(lang)`. Specs that need treesitter must `pending(...)` early when it returns false; the helper checks `parser/<lang>.{so,dylib,dll}` on `&runtimepath`, not just `language.add`, because the latter can silently succeed without a parser binary on disk.

## Public configuration API

```lua
require("sort-keys").setup({
  normalize_keys = true,
  comparator     = nil,         -- function(a, b, ctx) → bool|nil; falls back to default
  handlers       = { ... },     -- map of config_name → handler spec
})
```

A handler spec is `{ filetypes, builder, options, query_text, key_normalizer }`:

- `filetypes` — list of `vim.bo.filetype` values this spec applies to
- `builder` — Lua module exposing `build(bufnr, target, config) → outline | nil`. `config = { filetype, query_text, options, key_normalizer }`
- `options` — capability flags + per-container hints. Same shape as `lua/sort-keys/languages/<lang>/config.toml` (`can_sort_object` / `can_sort_array` / `can_deep` / `comment_aware` / `key_quoting` / `structural_separator` / `trailing_separator_allowed` / `mixed_key_types` / `parser_lang`)
- `query_text` — tree-sitter query string with `sortkeys.*` captures
- `key_normalizer` — optional `fun(text:string):string` injected into `config.key_normalizer`. Omit to use the builder's self-declared default (`builder.key_normalizer`); supply it to override how raw key text becomes the sort_key without replacing the builder.

Override rules (registry decides based on whether the user `handlers` key matches a built-in `config_name`):

| Match                                                                                    | Behavior                                                                                                                                              |
| ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `handlers.<config_name>` collides with a built-in (e.g. `handlers = { json = { ... } }`) | **Partial override**: `options` deep-merged on top of built-in. `builder` / `query_text` / `filetypes` are replaced if supplied, inherited otherwise. |
| Different `config_name` but `filetypes` collides with a built-in's                       | **User completely replaces** the built-in for that filetype (no field-level merge).                                                                   |
| Different `config_name` + new filetype                                                   | **New language**. `filetypes`, `builder`, `query_text`, and `options` are all required.                                                               |

`setup()` is idempotent: each call **replaces** the user-handlers map wholesale. Built-in handlers are never mutated. Internally, `lua/sort-keys/config.lua` lazy-requires `registry.set_user_handlers(opts.handlers or {})`; `registry.set_user_handlers` itself is internal — public callers go through `setup`.

## Adding a new language

The right Case to pick depends on what's different from JSON: the parser, the AST shape, or the key syntax. **`core/` is never touched in any of these cases**, by hard constraint.

### Case A — language reuses an existing parser (e.g. JSONC reusing tree-sitter-json)

1. `lua/sort-keys/languages/<lang>/config.toml`:
   - `parser_lang = "json"` (override; defaults to the filetype name)
   - `can_sort_object` / `can_sort_array` / `can_deep`
   - `comment_aware = true|false` (gates `core/comment_attach` delegation)
   - `structural_separator = ","` (opaque literal byte(s) — `;`, `\n`, etc. all work)
   - `trailing_separator_allowed = true|false`
   - `query_file = "sort-keys.scm"`
2. `lua/sort-keys/languages/<lang>/sort-keys.scm` using the `sortkeys.*` capture convention (`@sortkeys.container`, `@sortkeys.entry`, plus `@sortkeys.comment` if comment-aware) with the metadata `#set! sortkeys.kind "object"|"array"` / `#set! sortkeys.entry_kind "pair"|"element"`.
3. `lua/sort-keys/languages/<existing>/builder.lua` — append the new filetype to `M.filetypes`. The registry aggregates each builder's self-declared `filetypes`, so there's no central filetype → builder table to edit. The `BUILT_IN_BUILDERS` list in `registry.lua` only grows when an entirely new builder ships.
4. `tests/sort-keys/core/registry_spec.lua` — pin handler presence + capability flags.
5. `tests/sort-keys/<lang>_e2e_spec.lua` — a minimal e2e (comment-free smoke + at least one comment / separator case if applicable). Use `tests/support/treesitter.has_parser` for the underlying parser, not the filetype name.

Working example: `lua/sort-keys/languages/jsonc/config.toml` + `lua/sort-keys/languages/jsonc/sort-keys.scm` riding on `json` builder (note: the `jsonc/` directory has no `builder.lua` — it reuses `languages/json/builder.lua`).

### Case B — AST shape matches an existing builder's but the parser is independent (e.g. TypeScript ↔ tree-sitter-typescript inherits from tree-sitter-javascript)

Same as Case A, drop `parser_lang`. Make sure the query uses node names that actually exist in your grammar. Add the new filetype to the existing builder's `M.filetypes` table.

Working example: `languages/javascript/builder.lua` declares `M.filetypes = { javascript = "javascript", typescript = "typescript" }`, and `languages/typescript/` carries only `config.toml` + `sort-keys.scm`.

### Case C — key syntax differs from JSON (e.g. Lua bare identifiers, YAML bare keys, Nix dotted attrpath)

Create `lua/sort-keys/languages/<lang>/key_normalize.lua` (next to that language's builder) returning a single `fun(text:string):string` that takes the raw key node text and returns the canonical sort_key (quote stripping, escape decoding, dotted-key flattening if applicable); reuse the shared decoders in `core/key_escapes.lua` where the escape set overlaps JSON. The builder `require`s its sibling once as its self-declared `M.key_normalizer` default and calls the injected `config.key_normalizer` (not the concrete module) inside `build`, so a user can override normalization via the handler spec.

Working examples: `languages/{yaml,lua,toml,nix}/key_normalize.lua` — each handles that language's specific escape set and dotted-key shape.

### Case D — entirely different AST shape (Lua tables `{ a = 1, b = 2 }`, Nix attrset / formals / inherit, TOML inline_table + standard table + root-level pseudo-container)

Implement `lua/sort-keys/languages/<lang>/builder.lua` honoring the `build(bufnr, target, config) → outline | nil` contract by composing `core/builder_helpers`. Register the builder by appending it to `BUILT_IN_BUILDERS` in `registry.lua` (and self-declare its `M.filetypes`). Policy modules stay untouched — they only depend on the Outline shape; the shared `h.*` helpers cover all generic treesitter scaffolding so per-language code shrinks to the parts that are genuinely language-specific (entry classification, value→inner-container resolution, separator policy, deep-recursion strategy).

Working examples (in increasing complexity):

- `languages/lua/builder.lua` — single `table_constructor` AST for both object-like and array-like tables; container kind is decided dynamically by voting on whether any field is keyed.
- `languages/toml/builder.lua` — multiple container shapes (`inline_table` / `array` / `table` / `table_array_element` / synthesized root pseudo-container) with different separator policies per shape.
- `languages/nix/builder.lua` — multiple container shapes (`attrset` / `rec_attrset` / `let` / `list` / `formals` / `inherited_attrs`), AST quirk that interposes `binding_set` between container and entries (handled by `index_by_container_ancestor`), and the inherit-as-pinned-with-child container pattern.
- `languages/rust/builder.lua` — three container shapes (`field_declaration_list` / `field_initializer_list` / `use_list`), `..base` pinned via `base_field_initializer`, and the **attribute-as-comment** trick: `attribute_item` (`#[derive(...)]`, `#[serde(...)]`) is captured as `@sortkeys.comment` so `core/comment_attach` carries it with the next field at zero policy-layer cost — same dependency inversion the doc-comment case uses. Deep recursion walks one level into the value when the entry's own node isn't a container (`field_initializer` value is a `struct_expression` wrapping the inner `field_initializer_list`; `scoped_use_list` wraps the inner `use_list`).
- `languages/go/builder.lua` — three container shapes (`field_declaration_list` / `literal_value` / `import_spec_list`) but only two AST node types (`literal_value` is shared between struct, map, slice, and array bodies). The builder filters captured `literal_value` containers by "has any `keyed_element` direct child" so slice / array literals fall through to the no-sortable-structure path instead of silently producing an empty Outline. Per-container separator policy is local because Go uses two conventions: composite-literal bodies are `,`-separated; struct-definition and import-block bodies are newline-gapped with no inline separator.

## Writing a builder

A builder is a Lua module at `lua/sort-keys/languages/<lang>/builder.lua` that exports three things:

- `M.build(bufnr, target, config) → outline | nil` — the entry point called by `registry`
- `M.filetypes = { [filetype] = config_name, ... }` — self-declared filetype routing
- `M.key_normalizer = fun(text:string):string` — self-declared default key normalizer (the sibling `languages/<lang>/key_normalize`). The registry injects this — or a user override — as `config.key_normalizer`, which `build` consumes; `build` never calls a concrete normalizer directly.

### `config` argument

```lua
config = {
  filetype   = "json",    -- vim.bo.filetype of the current buffer
  query_text = "...",     -- tree-sitter query string from the .scm file
  options    = { ... },   -- parsed from the .toml; capability flags + per-container hints
}
```

### Standard `M.build` flow

The shared helpers cover steps 1, 3-5, and 6's gate. A builder typically looks like:

```lua
local h = require("sort-keys.core.builder_helpers")
local comment_attach = require("sort-keys.core.comment_attach")
-- The concrete normalizer is required only to declare the builder's default
-- (M.key_normalizer below); build() calls the injected config.key_normalizer.
local key_normalize = require("sort-keys.languages.<lang>.key_normalize")

function M.build(bufnr, target, config)
  -- 1. Validate. h.validate_options checks the baseline capability flags;
  --    pass `extras` to require language-specific options.
  if not h.validate_options(config.options) then return nil end

  -- 2. Get parser. Missing parsers are environmental → nil, not error.
  local lang = config.options.parser_lang or config.filetype
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or parser == nil then return nil end
  local root = parser:parse()[1]:root()

  -- 3-4. Run the query and triage matches. collect_matches returns the
  --      already-deduped entries plus a containers_by_key index.
  local query = vim.treesitter.query.parse(lang, config.query_text)
  local containers, entries, comments, containers_by_key =
    h.collect_matches(bufnr, root, query)
  if #containers == 0 then return nil end

  -- 5. Pick the target container. Cursor → 3-tier container_pick; selection
  --    → smallest container whose range covers target.range.
  local chosen = h.pick_innermost(containers, target)
  if not chosen then return nil end

  -- 6. Build the Outline. capability_allows is checked inside build_outline.
  return build_outline(chosen, {
    bufnr = bufnr,
    options = config.options,
    containers_by_key = containers_by_key,
    entries_by_parent = h.index_by_parent(entries),
    comments_by_parent = h.index_by_parent(comments),
  })
end
```

Language-specific overrides keep the same shape: YAML calls a local
`pick_innermost(containers, entries, target)` for its 2-entry-overlap rule;
Nix swaps `index_by_parent` for a local `index_by_container_ancestor`
(walks past `binding_set`); KDL / Lua / Pkl keep a local `collect_matches`
because their queries don't tag containers with `sortkeys.kind`.

### Capture convention

The `.scm` query must use these capture names:

| Capture               | `metadata` key                                | Meaning                                                         |
| --------------------- | --------------------------------------------- | --------------------------------------------------------------- |
| `@sortkeys.container` | `#set! sortkeys.kind "object"\|"array"`       | the sortable container node                                     |
| `@sortkeys.entry`     | `#set! sortkeys.entry_kind "pair"\|"element"` | one item inside the container                                   |
| `@sortkeys.key`       | —                                             | key node of a `"pair"` entry                                    |
| `@sortkeys.value`     | —                                             | value node of a `"pair"` entry (used to find nested containers) |
| `@sortkeys.comment`   | —                                             | comment node (only when `options.comment_aware`)                |

Languages whose container kind cannot be determined statically (e.g. Lua `table_constructor`) omit `sortkeys.kind` from the query and compute kind dynamically in `build_outline`.

### Grouping nodes by parent

`h.index_by_parent(items)` groups by each item's `node:parent()` via the shared `h.node_id_key` serialization, returning `node_id_key → list`. Builders consume it as `ctx.entries_by_parent[container.node_key]` and `ctx.comments_by_parent[container.node_key]`.

Builders that interpose an extra AST level between container and entries (e.g. Nix `binding_set`) keep a local `index_by_container_ancestor` that walks `node:parent()` upward until a captured container is hit; it still calls `h.node_id_key` for the lookup key.

### Building entries

Iterate entries in source-position order via `h.sort_entries_by_position(raw)` (the loop index becomes `anchor`):

```lua
local sorted_raw = h.sort_entries_by_position(raw)
for i, e in ipairs(sorted_raw) do
  local entry = {
    kind     = e.entry_kind,            -- "pair" | "element"
    range    = e.range,                 -- comment_attach may expand later
    sort_key = ctx.key_normalizer(...), -- injected; threaded as ctx.key_normalizer
                                        --   = config.key_normalizer or M.key_normalizer
    movable  = true,                    -- false for pinned entries (positional, spread,
                                        --   inherit, computed keys)
    anchor   = i,                       -- 1-based source-order index
    attached = {},
    child    = nil,
  }
  -- Recurse for :DeepSortKeys:
  local inner = ctx.containers_by_key[h.node_id_key(value_node)]
  if inner then entry.child = build_outline(inner, ctx) end
end
```

### Comment attachment

Call `comment_attach.attach` after all entries are built, only when `options.comment_aware`:

```lua
if ctx.options.comment_aware then
  local container_comments = ctx.comments_by_parent[container.node_key] or {}
  outline_entries = comment_attach.attach(outline_entries, container_comments)
end
```

### Returning the Outline

```lua
return {
  kind                       = container.kind,
  range                      = container.range,
  structural_separator       = ctx.options.structural_separator,
  trailing_separator_allowed = ctx.options.trailing_separator_allowed == true,
  entries                    = outline_entries,
}
```

Return `nil` (never a partial outline) when the container's kind is disabled. Use `h.capability_allows(container.kind, ctx.options)` at the top of `build_outline` for the standard gate; languages with dynamic kind voting (Lua, Pkl) call it after the vote completes.

### Registering the builder

Append the new builder to `BUILT_IN_BUILDERS` in `registry.lua` and self-declare its filetypes:

```lua
-- in languages/yourlang/builder.lua
M.filetypes = { yourlang = "yourlang" }

-- in registry.lua
local yourlang_builder = require("sort-keys.languages.yourlang.builder")
local BUILT_IN_BUILDERS = { ..., yourlang_builder }
```

The registry aggregates each builder's `M.filetypes` at startup — there is no central filetype → builder table to maintain separately.

## Conventions

- **Code comments and test name strings**: English, WHY-only — hidden constraints, intentional choices, non-obvious invariants. The plain "what" should be carried by identifiers and tests; comments must stand on their own without external references (no "see commit X" / "as per discussion in ADR Y" pointers — those rot when the surrounding context changes). Same rule against historical narrative: state the current invariant, not "previously X, now Y" or "we used to ship Z" — those rot the moment the next refactor lands.
- **Commit messages**: English, Conventional Commits style. Same self-contained rule (no ADR refs).
- **LSP noise**: busted globals (`pending`, `assert.is_*`, `describe`, `it`) and stylua-formatted but lua-language-server-flagged constructs are intentionally not chased with addon clones or settings hacks. Leave the diagnostics alone.
