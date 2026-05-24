# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
nix flake check   # all checks: tests, lint (selene), format (stylua)
nix fmt           # format lua/ plugin/ tests/ in place (stylua via treefmt)
```

Run a single spec file:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/sort-keys/core/comment_attach_spec.lua"
```

`plenary.nvim` is cloned automatically to `/tmp/sort-keys.nvim/plenary.nvim` on first run, or supplied via `PLENARY_DIR` (Nix sets this to `pkgs.vimPlugins.plenary-nvim`).

## Architecture: policy / detail separation

Two layers, hard-enforced by what each module is allowed to depend on:

**Policy (pure Lua, no `vim.*` / no treesitter / no buffer)** — `lua/sort-keys/core/`:

- `target.lua` — `cursor` / `selection` Target constructors.
- `policy.lua` — stable sort with anchor-aware movable slots, `:sort`-compat flag pipeline (`!`/`i`/`n`/`r/pat/`/`u`), and `apply_selection_overlay` for Visual partial sort.
- `walker.lua` — post-order recursion for `:DeepSortKeys`.
- `comment_attach.lua` — assigns each comment to an entry by spatial relationship (leading attaches to next, same-line trailing to prev) and expands the entry range to swallow it.
- `separator_normalize.lua` — inserts an inter-entry separator when missing and strips a trailing separator when the language forbids it. Treats `separator` as an opaque string so whitespace separators (`"\n"` for YAML block style) work the same as `,`.
- `unicode.lua`, `toml_loader.lua`, `strategies/key_normalize.lua` — pure helpers.

**Detail (treesitter / buffer / runtime lookup)**:

- `handlers/declarative/json_builder.lua` — runs the treesitter query, collects entries + comments, delegates "where does this comment go" to `comment_attach` when `toml.comment_aware`, returns an Outline.
- `core/applier.lua` — reads piece / gap text from the buffer, delegates inter-entry separator emission to `separator_normalize` when `outline.structural_separator` is set, writes back via `nvim_buf_set_text`.
- `core/registry.lua` — filetype → handler lookup, loads the per-language `.toml` and `.scm` at runtime.
- `command.lua` + `plugin/sort-keys.lua` — flag parsing and `:SortKeys` / `:DeepSortKeys` dispatch.

**Why this split**: the policy modules are reusable across languages — JSON, JSONC, future YAML / Lua / Nix all share the same `comment_attach` / `separator_normalize` / `policy.sort` / `walker`. The detail layer is what changes per language. Keeping the policy free of `vim.*` is what lets the test suite run the bulk of the specs as fast, deterministic unit tests on Outline literals.

## Development workflow: TDD (t-wada style)

Drive every behavioral change through the Red → Green → Refactor cycle, and **anchor the cycle on the policy layer**, not on e2e:

1. **Red** — write a failing spec in `tests/sort-keys/core/*_spec.lua` (or `tests/sort-keys/strategies/*_spec.lua`) that expresses the new rule as an assertion on an Outline literal / pure-Lua input. The test name encodes the WHY of the rule. Run `nix flake check` and confirm it fails for the expected reason — not on a typo or a missing require.
2. **Green** — make it pass with the smallest possible change to a policy module (`core/*.lua` or `strategies/*.lua`). Do not touch `vim.*`, treesitter, or the buffer to satisfy a policy test; if you feel the need to, the test is in the wrong layer.
3. **Refactor** — only with green tests. Policy modules must stay free of `vim.*` / treesitter / buffer dependencies, so refactoring is bounded by the layering rule above.

Triangulate inside the policy layer: prefer adding a second failing policy spec that forces the generalization over jumping straight to e2e. Detail and e2e specs (`handlers/declarative/*_spec.lua`, `<lang>_e2e_spec.lua`) come **after** the policy is green, and only to pin the delegation contract or smoke-check the wiring — they are not where new behavior is designed.

This is why the layering is hard-enforced: the policy modules being pure Lua is what makes the Red step cheap enough to do honestly every time.

## Test policy

`tests/sort-keys/core/*_spec.lua` and `tests/sort-keys/strategies/*_spec.lua` are the **emphasized layer** — they exercise pure policy on plain-Lua fixtures and should stay heavyweight (every rule of `comment_attach`, every separator edge case, every `:sort` flag, etc.).

Detail and e2e tests are smaller on purpose:

- `tests/sort-keys/handlers/declarative/*_spec.lua` pins the **delegation contract** (e.g., "when `toml.comment_aware = true`, the entry range gets expanded by `comment_attach`"), not every comment shape.
- `tests/sort-keys/<lang>_e2e_spec.lua` is a smoke-level check that the wired pipeline still produces correct buffer text after reorder.
- `tests/support/treesitter.lua` exposes `has_parser(lang)`. Specs that need treesitter must `pending(...)` early when it returns false; the helper checks `parser/<lang>.{so,dylib,dll}` on `&runtimepath`, not just `language.add`, because the latter can silently succeed without a parser binary.

## Outline contract

The shape every builder returns and every consumer reads:

```lua
outline = {
  kind        = "object" | "array",
  range       = { srow, scol, erow, ecol },  -- 0-indexed, end-exclusive
  structural_separator       = ",",   -- opaque to policy; per-language
  trailing_separator_allowed = true,  -- per-language capability

  entries = {
    { kind = "pair" | "element",
      sort_key = "...",                        -- logical key after normalize
      range = { srow, scol, erow, ecol },      -- may be expanded by comment_attach
      movable = true,                          -- false = anchored in place
      anchor = 1,                              -- 1-based source-order index
      attached = {},                           -- reserved
      child = nil | outline },                 -- nested container for deep sort
  },
}
```

`walker.recurse_children` and `policy.shallow_copy_outline` propagate `structural_separator` and `trailing_separator_allowed` — drop those copies and the applier silently skips normalization at the root.

## Adding a new language

### Case A — language reuses an existing parser (e.g. JSONC reusing tree-sitter-json)

1. `lua/sort-keys/handlers/declarative/<lang>.toml`:
   - `parser_lang = "json"` (override; defaults to the filetype name)
   - `can_sort_object` / `can_sort_array` / `can_deep`
   - `comment_aware = true|false` (gates `comment_attach`)
   - `structural_separator = ","` (literal byte(s) — `;`, `\n`, etc. are fine)
   - `trailing_separator_allowed = true|false`
   - `query_file = "sort-keys.scm"`
2. `queries/<lang>/sort-keys.scm` using the `sortkeys.*` capture convention (`@sortkeys.container`, `@sortkeys.entry`, `@sortkeys.key`, `@sortkeys.value`, plus `@sortkeys.comment` if comment-aware) with the metadata `#set! sortkeys.kind` / `#set! sortkeys.entry_kind`.
3. `lua/sort-keys/core/registry.lua` — add `<lang> = json_builder` to `DECLARATIVE_BUILDERS`.
4. `tests/sort-keys/core/registry_spec.lua` — pin handler presence + capabilities.
5. `tests/sort-keys/<lang>_e2e_spec.lua` — minimal e2e (comment-free smoke + at least one comment / separator case if applicable). Use `tests/support/treesitter.lua` `has_parser` for the underlying parser, not the filetype name.

No policy file is touched. Capability flips behavior.

### Case B — AST shape matches JSON's but the parser is independent

Same as Case A, drop `parser_lang` (filetype name is the parser name). Make sure your query uses node names that exist in your grammar.

### Case C — key syntax differs from JSON (e.g. Lua bare identifiers, YAML bare keys)

`json_builder.lua` currently hardcodes `key_normalize.json(key_text)` for pair entries. Extending to other key syntaxes is the natural future change:

1. Add `M.lua` / `M.yaml` / ... functions to `strategies/key_normalize.lua`.
2. Have `json_builder` dispatch via `config.toml.key_normalize_strategy` (new field).
3. Each `.toml` declares its strategy.

Until this extension exists, languages with non-JSON key syntax need their own builder.

### Case D — entirely different AST shape (Lua tables `{ a = 1, b = 2 }`, Nix attrset, YAML block-style)

Implement `lua/sort-keys/handlers/declarative/<lang>_builder.lua` honoring the `build(bufnr, target, config) -> outline | nil` contract, then register it in `DECLARATIVE_BUILDERS`. Policy modules stay untouched — they only depend on the Outline shape.

## Conventions

- Code comments and test name strings: English, WHY-only (hidden constraints, intentional choices, non-obvious invariants). The plain "what" should be carried by identifiers and tests; comments must stand on their own without external references.
- Commit messages: English, Conventional Commits style. Same self-contained rule.
- LSP diagnostics from busted globals (`pending`, `assert.is_*`) are noise. Do not chase them with addon clones or settings hacks; leave them alone.
