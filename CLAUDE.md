# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
nix flake check                 # everything: tests + lint (selene) + format (stylua) + git-hooks
nix fmt                         # apply stylua formatting in place
nix run .#default               # launch wrapped nvim with sort-keys.nvim + 7 tree-sitter parsers bundled
nix run .#dev                   # launch nvim that loads sort-keys.nvim from cwd (live-edit dev launcher)
nix run .#vhs                   # regenerate vhs/demo.gif from vhs/demo.tape
```

Run a single spec file:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/sort-keys/core/comment_attach_spec.lua"
```

`plenary.nvim` is cloned to `/tmp/sort-keys.nvim/plenary.nvim` on first run, or supplied via `PLENARY_DIR` (Nix sets this to `pkgs.vimPlugins.plenary-nvim`). Tree-sitter parsers for the 7 supported filetypes (`javascript` / `json` / `lua` / `nix` / `toml` / `typescript` / `yaml`) are bundled by the wrapped nvim used in `nix run`, so `:SortKeys` works out of the box without a user `~/.local/share/nvim/site/` install.

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
        │                       built-in:  handlers/<lang>.toml + queries/<lang>/sort-keys.scm (on disk)
        │                       user:      setup({handlers={...}}) injected at runtime
        ▼
lua/sort-keys/handlers/         runs the per-language treesitter query, collects
  <lang>_builder.lua            entries + comments, normalizes each sort_key via
        │                       strategies/key_normalize.<lang>, optionally delegates
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
core/registry.lua        ──require──────────►   core/toml_loader, handlers/<lang>_builder × 6
core/applier.lua         ──require──────────►   core/separator_normalize
core/walker.lua          ──require──────────►   core/policy
core/policy.lua          ──require──────────►   core/unicode
handlers/<lang>_builder  ──require──────────►   strategies/key_normalize, core/comment_attach, core/container_pick

(no incoming requires)                          core/{comment_attach, separator_normalize,
                                                     container_pick, unicode}
```

So `comment_attach` / `separator_normalize` / `container_pick` / `policy`
never reach up to a builder or to `vim.*`; the builder reaches down to
them through the shared Outline abstraction. **This is the dependency
inversion that makes the policy test suite pure-Lua**: a spec can
`require("sort-keys.core.policy")` and feed it a literal Outline without
spinning up nvim or treesitter.

Two known places where the inversion is only partial:

- `registry.lua` `require`s the six built-in builder modules directly.
  Self-registration via `builder.M.filetypes` keeps filetype→builder
  mapping out of `registry`, but the builder list itself is still
  hardcoded. (User handlers escape this via `setup({handlers={...}})`.)
- `command.lua` `require`s `registry` directly; the dispatch glue and
  the lookup layer are at the same abstraction level here, so no
  inversion is meaningful.

### Policy layer (pure Lua, no `vim.*` / no treesitter / no buffer)

Lives in `lua/sort-keys/core/` and `lua/sort-keys/strategies/`. Operates entirely on Outline literals and plain Lua tables. Each file's job:

- `target.lua` — `cursor` / `selection` Target constructors.
- `policy.lua` — stable sort, anchor-aware movable slots, `:sort`-compat flags (`!`/`i`/`n`/`r/pat/`/`u`), custom `comparator`, `apply_selection_overlay` for Visual partial sort.
- `walker.lua` — post-order recursion for `:DeepSortKeys`; propagates `structural_separator` / `trailing_separator_allowed` into child copies.
- `comment_attach.lua` — assigns each comment to an entry by spatial relationship (leading attaches to the next entry, same-line trailing attaches to the previous) and expands the entry range to swallow it. **Walks the original entry ranges**, not the in-progress expanded ones, so back-to-back leading-comment blocks routing into different entries don't accidentally collapse onto the previous entry.
- `separator_normalize.lua` — inserts the inter-entry separator when missing and strips a trailing separator when the language forbids it. Treats `separator` as an opaque byte string, so whitespace separators (`"\n"` for YAML block style, `" "` for Nix lists / `inherited_attrs`) work the same as `,` / `;`.
- `container_pick.lua` — cursor → innermost container resolution with a 3-tier fallback (strict containment → same-row leftmost start → row-span innermost area), shared by builders.
- `unicode.lua`, `toml_loader.lua` — pure helpers.
- `strategies/key_normalize.lua` — `M.json` / `M.yaml` / `M.js` / `M.lua` / `M.toml` / `M.nix`, each turns a raw key node text into the canonical sort_key (quote stripping + per-language escape decoding).

### Detail layer (treesitter / buffer / runtime lookup)

- `lua/sort-keys/handlers/<lang>_builder.lua` — runs the per-language treesitter query and returns an Outline. Six concrete builders today: `json_builder` (also serves `jsonc`), `yaml_builder`, `javascript_builder` (also serves `typescript`), `lua_builder`, `toml_builder`, `nix_builder`. Each `M.filetypes = { <ft> = <config_name>, ... }` is self-declared so the registry doesn't hardcode filetype → builder mapping.
- `lua/sort-keys/core/applier.lua` — reads piece / gap text from the buffer, delegates inter-entry separator emission to `separator_normalize` when `outline.structural_separator` is set, writes back via `nvim_buf_set_text`.
- `lua/sort-keys/core/registry.lua` — built-in handlers come from `handlers/<config_name>.toml` + `queries/<config_name>/sort-keys.scm` on `&runtimepath`. User handlers come from `set_user_handlers(specs)` (called from `config.setup`). Same-config-name overrides deep-merge over the built-in spec.
- `lua/sort-keys/command.lua` + `plugin/sort-keys.lua` — flag parsing and `:SortKeys` / `:DeepSortKeys` dispatch.

### Why this split

The policy modules are reusable across languages — JSON, JSONC, YAML, JavaScript, TypeScript, Lua, TOML, Nix (and future languages) all share the same `comment_attach` / `separator_normalize` / `policy.sort` / `walker`. The detail layer is what changes per language. Keeping the policy layer free of `vim.*` lets the bulk of the spec suite run as fast, deterministic unit tests on Outline literals — which is what makes the TDD Red step cheap enough to do honestly every time.

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
      movable  = true,                        -- false = pinned at its anchor slot
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

`movable = false` entries stay at their `anchor` index after sorting; the movable entries fill the remaining slots in sort_key order. This is what powers (a) language-specific pins (Lua positional fields, JS spread, Nix `inherit`, `...` ellipses), (b) the visual-range overlay (entries outside the selection get `movable = false` so only the selected ones reorder).

## Development workflow: TDD (t-wada style)

Drive every behavioral change through the Red → Green → Refactor cycle, and **anchor the cycle on the policy layer**, not on e2e:

1. **Red** — write a failing spec in `tests/sort-keys/core/*_spec.lua` (or `tests/sort-keys/strategies/*_spec.lua`) that expresses the new rule as an assertion on an Outline literal / pure-Lua input. The test name encodes the WHY of the rule. Run `nix flake check` and confirm it fails for the expected reason — not on a typo or a missing require.
2. **Green** — make it pass with the smallest possible change to a policy module (`core/*.lua` or `strategies/*.lua`). Do not touch `vim.*`, treesitter, or the buffer to satisfy a policy test; if you feel the need to, the test is in the wrong layer.
3. **Refactor** — only with green tests. Policy modules must stay free of `vim.*` / treesitter / buffer dependencies, so refactoring is bounded by the layering rule above.

**Triangulate inside the policy layer**: prefer adding a second failing policy spec that forces the generalization over jumping straight to e2e. Detail and e2e specs (`handlers/*_spec.lua`, `<lang>_e2e_spec.lua`) come **after** the policy is green, and only to pin the delegation contract or smoke-check the wiring — they are not where new behavior is designed.

If a policy spec doesn't feel like the right way to express the rule, the rule probably isn't a policy rule (= it belongs in a per-language builder, not in `core/`).

## Test policy

`tests/sort-keys/core/*_spec.lua` and `tests/sort-keys/strategies/*_spec.lua` are the **emphasized layer** — they exercise pure policy on plain-Lua fixtures and should stay heavyweight (every rule of `comment_attach`, every separator edge case, every `:sort` flag, every key normalization escape, etc.).

Detail and e2e tests are intentionally thinner:

- `tests/sort-keys/handlers/*_spec.lua` pins the **delegation contract** ("when `options.comment_aware = true`, the entry range gets expanded by `comment_attach`"; "inherit binding is movable=false with a child container"), not every comment shape.
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

A handler spec is `{ filetypes, builder, options, query_text }`:

- `filetypes` — list of `vim.bo.filetype` values this spec applies to
- `builder` — Lua module exposing `build(bufnr, target, config) → outline | nil`. `config = { filetype, query_text, options }`
- `options` — capability flags + per-container hints. Same shape as `lua/sort-keys/handlers/<lang>.toml` (`can_sort_object` / `can_sort_array` / `can_deep` / `comment_aware` / `key_quoting` / `structural_separator` / `trailing_separator_allowed` / `mixed_key_types` / `parser_lang`)
- `query_text` — tree-sitter query string with `sortkeys.*` captures

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

1. `lua/sort-keys/handlers/<lang>.toml`:
   - `parser_lang = "json"` (override; defaults to the filetype name)
   - `can_sort_object` / `can_sort_array` / `can_deep`
   - `comment_aware = true|false` (gates `core/comment_attach` delegation)
   - `structural_separator = ","` (opaque literal byte(s) — `;`, `\n`, etc. all work)
   - `trailing_separator_allowed = true|false`
   - `query_file = "sort-keys.scm"`
2. `queries/<lang>/sort-keys.scm` using the `sortkeys.*` capture convention (`@sortkeys.container`, `@sortkeys.entry`, plus `@sortkeys.comment` if comment-aware) with the metadata `#set! sortkeys.kind "object"|"array"` / `#set! sortkeys.entry_kind "pair"|"element"`.
3. `lua/sort-keys/handlers/<existing>_builder.lua` — append the new filetype to `M.filetypes`. The registry aggregates each builder's self-declared `filetypes`, so there's no central filetype → builder table to edit. The `BUILDERS` list in `registry.lua` only grows when an entirely new builder ships.
4. `tests/sort-keys/core/registry_spec.lua` — pin handler presence + capability flags.
5. `tests/sort-keys/<lang>_e2e_spec.lua` — a minimal e2e (comment-free smoke + at least one comment / separator case if applicable). Use `tests/support/treesitter.has_parser` for the underlying parser, not the filetype name.

Working example: `lua/sort-keys/handlers/jsonc.toml` + `queries/jsonc/sort-keys.scm` riding on `json_builder`.

### Case B — AST shape matches an existing builder's but the parser is independent (e.g. TypeScript ↔ tree-sitter-typescript inherits from tree-sitter-javascript)

Same as Case A, drop `parser_lang`. Make sure the query uses node names that actually exist in your grammar. Add the new filetype to the existing builder's `M.filetypes` table.

Working example: `handlers/javascript_builder.lua` declares `M.filetypes = { javascript = "javascript", typescript = "typescript" }`.

### Case C — key syntax differs from JSON (e.g. Lua bare identifiers, YAML bare keys, Nix dotted attrpath)

Add an `M.<lang>(text)` function to `lua/sort-keys/strategies/key_normalize.lua` that takes the raw key node text and returns the canonical sort_key (quote stripping, escape decoding, dotted-key flattening if applicable). Have the builder call `key_normalize.<lang>` instead of `key_normalize.json`.

Working examples: `strategies/key_normalize.{yaml,lua,toml,nix}` — each handles that language's specific escape set and dotted-key shape.

### Case D — entirely different AST shape (Lua tables `{ a = 1, b = 2 }`, Nix attrset / formals / inherit, TOML inline_table + standard table + root-level pseudo-container)

Implement `lua/sort-keys/handlers/<lang>_builder.lua` honoring the `build(bufnr, target, config) → outline | nil` contract. Register the builder by appending it to `BUILDERS` in `registry.lua` (and self-declare its `M.filetypes`). Policy modules stay untouched — they only depend on the Outline shape.

Working examples (in increasing complexity):

- `handlers/lua_builder.lua` — single `table_constructor` AST for both object-like and array-like tables; container kind is decided dynamically by voting on whether any field is keyed.
- `handlers/toml_builder.lua` — five container shapes (`inline_table` / `array` / `table` / `table_array_element` / synthesized root pseudo-container) with three different separator policies.
- `handlers/nix_builder.lua` — six container shapes (`attrset` / `rec_attrset` / `let` / `list` / `formals` / `inherited_attrs`), AST quirk that interposes `binding_set` between container and entries (handled by `index_by_container_ancestor`), and the inherit-as-pinned-with-child container pattern.

## Conventions

- **Code comments and test name strings**: English, WHY-only — hidden constraints, intentional choices, non-obvious invariants. The plain "what" should be carried by identifiers and tests; comments must stand on their own without external references (no "see commit X" / "as per discussion in ADR Y" pointers — those rot when the surrounding context changes).
- **Commit messages**: English, Conventional Commits style. Same self-contained rule (no ADR refs).
- **LSP noise**: busted globals (`pending`, `assert.is_*`, `describe`, `it`) and stylua-formatted but lua-language-server-flagged constructs are intentionally not chased with addon clones or settings hacks. Leave the diagnostics alone.
