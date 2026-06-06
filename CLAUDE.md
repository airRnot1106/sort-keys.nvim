# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
nix flake check                 # everything: tests + lint (selene) + format (stylua) + git-hooks
nix fmt                         # apply stylua formatting in place
nix run .#default               # launch wrapped nvim with sort-keys.nvim + bundled tree-sitter parsers
nix run .#dev                   # launch nvim that loads sort-keys.nvim from cwd (live-edit dev launcher)
nix run .#vhs                   # regenerate vhs/demo.gif from vhs/demo.tape
```

Run a single spec file:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/sort-keys/core/render_spec.lua"
```

`plenary.nvim` is cloned to `/tmp/sort-keys.nvim/plenary.nvim` on first run, or supplied via `PLENARY_DIR` (Nix sets this to `pkgs.vimPlugins.plenary-nvim`). Tree-sitter parsers for the supported filetypes are bundled by the wrapped nvim used in `nix run`, so `:SortKeys` works out of the box. The headless `nix/test.nix` runner uses a parserless neovim, so e2e specs that need a parser `pending(...)` there — the pure `core/` specs carry the weight.

Supported filetypes today: **json**, **jsonc**, **javascript** (declarative packs), and **lua** (a custom extractor). Everything else is added through the language-pack mechanism below.

## Architecture: parse → transform → print (functional core / imperative shell)

The whole plugin is one pipeline along a horizontal axis (data flow) crossed with a vertical axis (purity). The only boundary line is **"does it touch nvim / treesitter / buffer?"**

```
                 parse                transform               print
               (text→IR)             (IR→IR)               (IR→text)
                  │                      │                     │
 SHELL  command ─ extract.lua ───────────┼──────────────── apply.lua
 (impure)        (buffer + treesitter)   │                 (nvim_buf_set_text)
 ───────────────────────────────────────┼──────────────────────────────────
 CORE                          sort.lua = order ∘ placement ∘ traverse
 (pure)                        + render.lua (IR → string)
```

### Data flow

```
:SortKeys / :DeepSortKeys / :[range]SortKeys
        │
        ▼
plugin/sort-keys.lua     user command registration (range, bang, nargs)
        │
        ▼
lua/sort-keys/command.lua parses :sort-compat flags (!/i/n + /pat/), builds a
        │                 Target (cursor or line-wise selection), threads the
        │                 configured comparator into the order spec, then drives
        │                 the four stages below.
        ▼
lua/sort-keys/registry.lua filetype → language pack { options, query_text,
        │                 key_normalizer }. Built-in packs are declarative files
        │                 on &runtimepath; user packs come from setup({handlers}).
        ▼
lua/sort-keys/extract.lua PARSE (dispatcher). Routes to pack.extractor (custom)
        │                 or the generic extractor; both compose extract_support,
        │                 which picks the target container, folds comments into
        │                 per-entry lead/tail (core/comment_fold), OBSERVES the
        │                 inter-entry framing (prefix/separator/joint/trailing/
        │                 suffix), and returns a self-renderable IR.
        ▼ IR
lua/sort-keys/core/sort.lua TRANSFORM. order × placement × traverse. Pure
        │                 reorder of entries; never touches framing/separators.
        ▼ IR'
lua/sort-keys/core/render.lua PRINT (pure). IR → string by one separator rule.
        │
        ▼ string
lua/sort-keys/apply.lua   nvim_buf_set_text over the container's range.
```

### Dependency direction

Runtime data flows left→right / top→bottom; the `require` graph points the
other way — every `core/` module is a pure leaf that only knows the IR shape,
and the shell pulls it in:

```
high-level / impure        →  require            ←  low-level / pure
──────────────────────                              ──────────────────────
command.lua          ──require──►  config, registry, extract, apply,
                                   core/{sort, order, render}
extract.lua          ──require──►  generic_extractor   (custom is reached at
                                   runtime via pack.extractor, never required)
generic_extractor.lua ─require──►  extract_support
languages/<lang>/extractor.lua ─►  extract_support
extract_support.lua  ──require──►  core/{comment_fold, pos}
registry.lua         ──require──►  core/toml_loader (+ dynamically a pack's
                                   normalize.lua / extractor.lua by config_name)
config.lua           ──require──►  registry
apply.lua            ──require──►  (nothing; command calls render, hands it the string)
sort.lua             ──require──►  core/{order, placement, traverse, ir}
traverse.lua         ──require──►  core/ir
comment_fold.lua     ──require──►  core/pos
languages/<lang>/normalize.lua ─►  core/key_escapes

(pure leaves, no requires)         core/{ir, order, placement, render, pos,
                                        key_escapes, toml_loader}
```

A spec can `require("sort-keys.core.sort")` and feed it a literal IR with no
nvim or treesitter running. That is what keeps the TDD Red step cheap.

### Core layer (pure Lua, no `vim.*` / no treesitter / no buffer)

`lua/sort-keys/core/` operates entirely on IR literals and plain tables.

- `ir.lua` — IR types + forward-compatible `copy_entry` / `copy_container` (forward every field via `pairs`, so a new IR field is never silently dropped at a rebuild site).
- `order.lua` — the ORDER axis: turn an order spec into a 3-way comparator. Flags (`reverse`/`ignore_case`/`numeric`/`pattern`) wrap a base; `spec.comparator` (`fun(a,b,ctx)->bool|nil`) **swaps the base** and falls back to the default when it returns nil. `valid_pattern` rejects malformed Lua patterns so `:SortKeys /pat/` degrades instead of crashing.
- `placement.lua` — the PLACEMENT axis: map the comparator onto entry slots honoring pins (`movable=false`) and fences (`fence=true`). One pure function powers language pins, fences, and Visual partial sort. Stable (ties keep source order).
- `traverse.lua` — the TRAVERSAL axis: `shallow` (this container) vs `deep` (post-order recursion into `entry.child`).
- `sort.lua` — composes order × placement × traverse into one IR→IR function.
- `render.lua` — IR → string by the single separator rule (see "Separators").
- `comment_fold.lua` — **parse-stage** pure helper (used only by `extract`, never by the transform spine): given data-entry ranges + comment ranges, assigns each comment to an entry and returns an expanded "block" range per entry. Same-line trailing → previous entry; own-line → next entry; trailing after the last entry → last entry.
- `pos.lua` — pure buffer-position / range primitives (`lt`, `contains`, `rows_cover`, `row_in_span`, `rows_overlap`) shared by `extract` and `comment_fold`.
- `key_escapes.lua` — escape-decoding primitives (`unescape_json`, `unescape_js`, `utf8_encode`, `strip_double_quotes`) reused by per-language normalizers.
- `toml_loader.lua` — minimal `key = "string" | true | false` reader for `config.toml`.

### Shell layer (treesitter / buffer / runtime lookup)

- `extract.lua` — the **parse-stage dispatcher**: runs `pack.extractor` (a custom extractor) when the pack ships one, else the generic extractor. command calls this and stays oblivious to which.
- `generic_extractor.lua` — the **generic extractor**, driven entirely by a pack's `sort-keys.scm` captures + `config.toml`, so a JSON-shaped language needs no per-language Lua. Supplies only `collect` (query triage by the `sortkeys.*` captures, including the pin/fence capture sets).
- `extract_support.lua` — the **shared scaffolding** both extractors compose: target picking (cursor → smallest containing; line-wise selection → smallest container whose rows cover it, falling back to the one whose rows contain the first selected line), `build_container` (frame observation, comment folding, separator peeling, deep recursion), the Visual overlay, and the `run(…, collect)` orchestrator. An extractor supplies only its `collect`.
- `languages/<lang>/extractor.lua` — a **custom extractor** for an irregular AST whose `collect` the generic query can't express (e.g. `languages/lua/extractor.lua`: a `table_constructor`'s kind is voted from its fields). Supplies only `collect`; composes `extract_support`.
- `apply.lua` — renders the IR and writes it back with `nvim_buf_set_text`.
- `registry.lua` — `filetype → config_name` (built-in `BUILT_IN_FILETYPES`), loads `languages/<config_name>/config.toml` + `sort-keys.scm` + optional `normalize.lua` + optional `extractor.lua` off `&runtimepath` (a present `extractor.lua` becomes `pack.extractor`). User packs from `set_user_handlers(specs)` override/extend by config name.
- `config.lua` — public `setup`. Idempotent: each call rebuilds from defaults, so options and the user-handler map are replaced wholesale.
- `command.lua` + `plugin/sort-keys.lua` — flag parsing and `:SortKeys` / `:DeepSortKeys` dispatch.

## IR contract

The shape `extract` returns, `sort`/`render` consume:

```lua
Container = {
  kind      = "object" | "array",
  range     = { srow, scol, erow, ecol },  -- 0-indexed, end-exclusive; apply overwrites this span

  -- OBSERVED by extract as opaque bytes; consumed only by render. The transform
  -- spine never reads these.
  prefix    = "{\n  ",   -- container open up to the first entry
  suffix    = "\n}",     -- after the last entry's data to the close
  separator = ",",       -- inter-entry delimiter ("" if whitespace-gapped)
  joint     = "\n  ",    -- whitespace between separator and the next entry
  trailing  = false,     -- did the source put a separator after the last entry?

  entries = {
    {
      sort_key = "...",       -- logical key after normalization (drives ordering)
      text     = "\"a\": 1",  -- raw source span; rendered verbatim when child == nil
      lead     = "",          -- own-line leading trivia (comments) that travels with the entry
      tail     = "",          -- same-line trailing trivia that travels with the entry
      movable  = true,        -- false = pinned at its source slot
      anchor   = 1,           -- 1-based source-order index
      fence    = nil,         -- true (with movable=false) = movables cannot cross it
      range    = { ... },     -- block range incl. folded comments; used by the selection overlay
      child    = nil,         -- nested Container for deep sort
      pre      = "\"a\": ",   -- text before child (only when child ~= nil)
      post     = "",          -- text after child  (only when child ~= nil)
    },
  },
}
```

`movable = false` entries stay at their `anchor` slot; movable entries fill the
rest in sorted order. This powers (a) language pins and (b) the Visual overlay
(entries whose rows don't overlap the selection are flipped to `movable=false`).
A **fence** (`movable=false, fence=true`) additionally blocks movable entries
from crossing it (order-sensitive pins); plain pins are permeable.

## Separators: observe, don't configure

There is no separator configuration and no normalization pass. `extract`
OBSERVES the framing from the source — `separator` is the first non-whitespace
run after the first entry's data (leading whitespace skipped, so a comma at the
start of the next line is still seen); `joint`/`prefix`/`suffix`/`trailing` are
sliced likewise. `render` reproduces them with one language-agnostic rule:

```
prefix + for each entry i of n:
           lead + content(entry)
           + (i < n ? separator + tail + joint : (trailing ? separator) + tail)
         + suffix
```

`tail` (a same-line trailing comment) travels with its entry; `separator` is
slot-bound, so it drops off whichever entry lands last and is re-emitted on the
new last slot. The separator that sits between an entry's data and its trailing
comment is peeled out of the tail at parse time (`peel_separator`, which peels
from whichever end carries it) and re-emitted by render. This is what makes a
trailing comment round-trip, and normalizes a leading-comma layout to the usual
trailing style.

## Development workflow: TDD (t-wada style)

Drive every behavioral change Red → Green → Refactor, **anchored on the core (pure) layer**, not on e2e:

1. **Red** — write a failing spec in `tests/sort-keys/core/*_spec.lua` (or `tests/sort-keys/languages/<lang>/normalize_spec.lua`) expressing the rule as an assertion on an IR literal / pure input. The test name encodes the WHY. Run it and confirm it fails for the expected reason.
2. **Green** — smallest change to a `core/*.lua` (or a `languages/<lang>/normalize.lua`). Do not touch `vim.*` / treesitter / buffer to satisfy a core test; if you need to, the test is in the wrong layer.
3. **Refactor** — only with green tests; the layering rule (core stays nvim-free) bounds it.

E2E specs (`tests/sort-keys/<lang>_e2e_spec.lua`) come **after** core is green, only to smoke-check the wired pipeline produces correct buffer text. New behavior is designed in the core specs, not in e2e.

## Test policy

- `tests/sort-keys/core/*_spec.lua` are the **emphasized layer** — pure policy on plain-Lua fixtures: `ir`, `order` (every flag + the comparator base swap), `placement` (pins/fences/overlay/stability), `traverse`, `sort`, `render` (every separator edge), `comment_fold`, `pos`. Keep them heavyweight.
- `tests/sort-keys/languages/<lang>/normalize_spec.lua` loads each `normalize.lua` directly (no nvim) — still pure-policy tier.
- `tests/sort-keys/<lang>_e2e_spec.lua` is a thin smoke check of the wired pipeline (shallow/deep, separators, comments, selection).
- `tests/support/treesitter.lua` exposes `has_parser(lang)`; specs that need a parser `pending(...)` when it returns false. It checks for an actual `parser/<lang>.{so,dylib,dll}` on `&runtimepath`, not just `language.add`.

## Public configuration API

```lua
require("sort-keys").setup({
  comparator = nil,   -- fun(a, b, ctx) -> bool|nil; the ORDER-axis base swap, nil = default
  handlers   = {},    -- map of config_name → language-pack spec
})
```

(Key normalization is an always-on parse helper — there is no normalize toggle.)
`setup()` is idempotent: each call replaces options and the user-handler map
wholesale; built-in packs are never mutated.

A language-pack spec is `{ filetypes, options, query_text, key_normalizer, extractor }`:

- `filetypes` — list of `vim.bo.filetype` values this spec serves.
- `options` — same shape as `languages/<config_name>/config.toml`: `parser_lang` (+ `query_file` for built-ins). **No separator fields** — those are observed.
- `query_text` — tree-sitter query string with the `sortkeys.*` captures.
- `key_normalizer` — optional `fun(text:string):string`. Omit to fall back to the built-in `normalize.lua` for that config name (if any) or identity.
- `extractor` — optional custom extractor module (`{ extract(bufnr, target, pack, deep) }`) for an irregular AST. Omit to use the generic, query-driven extractor (the common case).

Override rules (registry decides by whether the user `handlers` key matches a built-in `config_name`):

| Match                                                           | Behavior                                                                                                                                    |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| key matches a built-in (e.g. `handlers = { json = {...} }`)     | **Partial override**: `options` deep-merged on top of the built-in; `query_text` / `key_normalizer` replace if supplied, inherit otherwise. |
| different key, but a `filetypes` entry collides with a built-in | **User wins** for that filetype.                                                                                                            |
| different key + new filetype                                    | **New language**: `filetypes`, `options`, `query_text` are all required.                                                                    |

## Adding a language (declarative)

`core/` is never touched. Add files under `lua/sort-keys/languages/<config_name>/`:

1. `config.toml` — capabilities + parser:
   - `parser_lang = "json"` (override; defaults to the filetype name — set it when reusing another grammar, e.g. jsonc on the json parser)
   - `query_file = "sort-keys.scm"`
   - (no separator/quoting fields — observed)
2. `sort-keys.scm` — the tree-sitter query using the `sortkeys.*` captures:

   | Capture               | Metadata                                      | Role                                                        |
   | --------------------- | --------------------------------------------- | ----------------------------------------------------------- |
   | `@sortkeys.container` | `#set! sortkeys.kind "object"\|"array"`       | the sortable container node                                 |
   | `@sortkeys.entry`     | `#set! sortkeys.entry_kind "pair"\|"element"` | one item inside the container                               |
   | `@sortkeys.key`       | —                                             | key node of a `"pair"` entry                                |
   | `@sortkeys.value`     | —                                             | value node of a `"pair"` (for deep recursion)               |
   | `@sortkeys.comment`   | —                                             | comment node                                                |
   | `@sortkeys.pin`       | —                                             | mark the entry `movable=false` (holds its slot; permeable)  |
   | `@sortkeys.fence`     | —                                             | mark the entry an impermeable pin (movables can't cross it) |

   `@sortkeys.pin` / `@sortkeys.fence` are collected as node-id sets independent of the entry pattern, so a member captured as both an entry and a fence keeps the flag even when a wildcard pattern also captures it. Use a pin for members whose position is meaningless to keyed entries (a method that should stay put); a fence for order-sensitive members (a JS spread / computed key, a Ruby `**splat`) where what sits before vs. after them matters.

3. `normalize.lua` (optional) — `fun(text:string):string` turning a raw key node's text into the sort_key (quote stripping, escape decoding); reuse `core/key_escapes`. Omit to inherit another pack's (e.g. jsonc `require`s json's) or fall back to identity.
4. Register the filetype: add `<filetype> = "<config_name>"` to `BUILT_IN_FILETYPES` in `registry.lua`.
5. `tests/sort-keys/<config_name>_e2e_spec.lua` — a minimal e2e (comment-free smoke + a comment/separator case if applicable). Gate on `tests/support/treesitter.has_parser` for the _parser_ name, not the filetype.

Working examples: `languages/json/` (config.toml + sort-keys.scm + normalize.lua), `languages/jsonc/` (rides on the json parser via `parser_lang = "json"` and `normalize.lua` re-exporting json's), and `languages/javascript/` (declarative, using `@sortkeys.pin` / `@sortkeys.fence` for methods / spreads / computed keys).

This generic path covers any language whose container/entry/key/value shape the
`sortkeys.*` query can express, including pins and fences. An irregular AST whose
`collect` the query can't express ships a **custom extractor**
`languages/<config_name>/extractor.lua` that supplies `collect` and composes
`extract_support`; the registry exposes it as `pack.extractor` and the dispatcher
routes to it. Working example: `languages/lua/extractor.lua` (a
`table_constructor`'s kind is voted from its fields — no static query can tag it).
The custom path is the escape hatch for the minority of languages the declarative
path can't reach.

## Conventions

- **Code comments and test name strings**: English, WHY-only — hidden constraints, intentional choices, non-obvious invariants. The plain "what" is carried by identifiers and tests; comments must stand on their own without external references (no "see commit X" / ADR pointers — those rot). State the current invariant, not "previously X, now Y".
- **Commit messages**: English, Conventional Commits style. Same self-contained rule.
- **LSP noise**: busted globals (`pending`, `assert.is_*`, `describe`, `it`) and stylua-formatted but lua-language-server-flagged constructs are intentionally not chased. Leave the diagnostics alone.
