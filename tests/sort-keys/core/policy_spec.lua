-- Tests only pin the public contract; internal helpers are deliberately left
-- unpinned so the implementation can refactor freely.

local function make_entry(key, anchor, opts)
  opts = opts or {}
  return {
    kind = "pair",
    sort_key = key,
    range = opts.range or { 0, 0, 0, 0 },
    movable = opts.movable ~= false,
    fence = opts.fence,
    anchor = anchor,
    attached = {},
    child = nil,
  }
end

local function make_outline(kind, entries)
  return {
    kind = kind,
    range = { 0, 0, 0, 0 },
    separator = ",",
    entries = entries,
  }
end

local function keys(outline)
  local out = {}
  for i, e in ipairs(outline.entries) do
    out[i] = e.sort_key
  end
  return out
end

describe("sort-keys.core.policy", function()
  local policy

  before_each(function()
    package.loaded["sort-keys.core.policy"] = nil
    policy = require("sort-keys.core.policy")
  end)

  describe("sort — default (no flags)", function()
    it("sorts an object Outline by sort_key ascending", function()
      local o = make_outline("object", {
        make_entry("c", 1),
        make_entry("a", 2),
        make_entry("b", 3),
      })
      local sorted = policy.sort(o, { flags = {}, normalize_keys = true })
      assert.same({ "a", "b", "c" }, keys(sorted))
    end)

    it("returns a new Outline without mutating the input entries order", function()
      local entries = { make_entry("c", 1), make_entry("a", 2) }
      local o = make_outline("object", entries)
      policy.sort(o, { flags = {}, normalize_keys = true })
      -- Original entries are left in declared order.
      assert.equals("c", entries[1].sort_key)
      assert.equals("a", entries[2].sort_key)
    end)

    it("is stable for equal keys (preserves anchor order)", function()
      local o = make_outline("object", {
        make_entry("a", 1),
        make_entry("a", 2),
        make_entry("a", 3),
      })
      local sorted = policy.sort(o, { flags = {}, normalize_keys = true })
      assert.equals(1, sorted.entries[1].anchor)
      assert.equals(2, sorted.entries[2].anchor)
      assert.equals(3, sorted.entries[3].anchor)
    end)
  end)

  describe("sort — :sort compat flags", function()
    it("flag `!` reverses the comparison order", function()
      local o = make_outline("object", {
        make_entry("a", 1),
        make_entry("c", 2),
        make_entry("b", 3),
      })
      local sorted = policy.sort(o, { flags = { reverse = true }, normalize_keys = true })
      assert.same({ "c", "b", "a" }, keys(sorted))
    end)

    it("flag `i` compares case-insensitively (casefold)", function()
      local o = make_outline("object", {
        make_entry("Beta", 1),
        make_entry("alpha", 2),
        make_entry("Gamma", 3),
      })
      local sorted = policy.sort(o, { flags = { ignore_case = true }, normalize_keys = true })
      assert.same({ "alpha", "Beta", "Gamma" }, keys(sorted))
    end)

    it("flag `n` compares numerically when tonumber succeeds on both sides", function()
      local o = make_outline("array", {
        make_entry("10", 1),
        make_entry("2", 2),
        make_entry("30", 3),
      })
      local sorted = policy.sort(o, { flags = { numeric = true }, normalize_keys = true })
      assert.same({ "2", "10", "30" }, keys(sorted))
    end)

    it("flag `n` falls back to string compare when tonumber fails on either side", function()
      local o = make_outline("array", {
        make_entry("10", 1),
        make_entry("apple", 2),
        make_entry("2", 3),
      })
      -- Mixed: with string fallback this remains a deterministic ordering
      -- driven by string comparison. We assert it does not raise and yields
      -- a stable, total ordering of the same multiset.
      local sorted = policy.sort(o, { flags = { numeric = true }, normalize_keys = true })
      assert.equals(3, #sorted.entries)
      local got = {}
      for _, e in ipairs(sorted.entries) do
        got[e.sort_key] = (got[e.sort_key] or 0) + 1
      end
      assert.equals(1, got["10"])
      assert.equals(1, got["apple"])
      assert.equals(1, got["2"])
    end)

    it("flag `r /pat/` compares the regex-extracted substring", function()
      local o = make_outline("array", {
        make_entry("item-30", 1),
        make_entry("item-2", 2),
        make_entry("item-10", 3),
      })
      local sorted = policy.sort(o, {
        flags = { regex = "%d+", numeric = true },
        normalize_keys = true,
      })
      assert.same({ "item-2", "item-10", "item-30" }, keys(sorted))
    end)

    it("flag `r /pat/` with a non-Lua pattern degrades to no-match instead of aborting", function()
      -- :sort's r/.../ takes a Vim regex; pasted verbatim it is frequently an
      -- invalid Lua pattern. string.match would raise and abort the entire
      -- sort, so the regex transform must be guarded and fall back to the full
      -- sort_key — a sortable buffer must never crash the command.
      local o = make_outline("object", {
        make_entry("b", 1),
        make_entry("a", 2),
        make_entry("c", 3),
      })
      local sorted = policy.sort(o, {
        flags = { regex = "[a-z" }, -- unclosed class: malformed Lua pattern
        normalize_keys = true,
      })
      assert.same({ "a", "b", "c" }, keys(sorted))
    end)

    it("flag `u` keeps only the first occurrence per key", function()
      local o = make_outline("object", {
        make_entry("a", 1),
        make_entry("b", 2),
        make_entry("a", 3),
        make_entry("b", 4),
        make_entry("c", 5),
      })
      local sorted = policy.sort(o, { flags = { unique = true }, normalize_keys = true })
      assert.same({ "a", "b", "c" }, keys(sorted))
      -- First-occurrence policy: anchors of the survivors are the smaller ones.
      local anchors = {}
      for _, e in ipairs(sorted.entries) do
        anchors[e.sort_key] = e.anchor
      end
      assert.equals(1, anchors.a)
      assert.equals(2, anchors.b)
      assert.equals(5, anchors.c)
    end)

    -- The applier needs the removed entries' ranges to recompute the
    -- container's prefix/gaps/suffix partition; otherwise it re-emits the
    -- dropped entries' source bytes. So dedup surfaces the removed entries
    -- on `outline.dropped` instead of discarding them outright.
    it("exposes the removed duplicates on outline.dropped", function()
      local o = make_outline("object", {
        make_entry("a", 1),
        make_entry("b", 2),
        make_entry("a", 3),
        make_entry("b", 4),
        make_entry("c", 5),
      })
      local sorted = policy.sort(o, { flags = { unique = true }, normalize_keys = true })
      assert.same({ "a", "b", "c" }, keys(sorted))
      assert.is_table(sorted.dropped)
      local dropped_anchors = {}
      for _, e in ipairs(sorted.dropped) do
        dropped_anchors[#dropped_anchors + 1] = e.anchor
      end
      table.sort(dropped_anchors)
      -- The second "a" (anchor 3) and second "b" (anchor 4) were removed.
      assert.same({ 3, 4 }, dropped_anchors)
    end)

    it("leaves outline.dropped empty when no flag removes anything", function()
      local o = make_outline("object", {
        make_entry("b", 1),
        make_entry("a", 2),
      })
      local sorted = policy.sort(o, { flags = {}, normalize_keys = true })
      assert.same({}, sorted.dropped)
    end)
  end)

  describe("sort — custom comparator", function()
    it("invokes the user comparator with (a, b, ctx) and respects its decision", function()
      local recorded
      local cmp = function(a, b, ctx)
        recorded = ctx
        return #a < #b
      end
      local o = make_outline("array", {
        make_entry("yyy", 1),
        make_entry("z", 2),
        make_entry("xx", 3),
      })
      local sorted = policy.sort(o, {
        flags = { reverse = false },
        comparator = cmp,
        normalize_keys = true,
      })
      assert.same({ "z", "xx", "yyy" }, keys(sorted))
      assert.is_table(recorded)
      assert.equals("array", recorded.kind)
      assert.is_table(recorded.flags)
    end)
  end)

  describe("sort — movable=false anchored entries", function()
    it("keeps non-movable entries at their original anchor index", function()
      local o = make_outline("object", {
        make_entry("c", 1, { movable = true }),
        make_entry("a", 2, { movable = true }),
        make_entry("b", 3, { movable = false }),
      })
      local sorted = policy.sort(o, { flags = {}, normalize_keys = true })
      -- The third position remains "b" because it is anchored;
      -- "a" and "c" are reordered among the movable slots.
      assert.equals("a", sorted.entries[1].sort_key)
      assert.equals("c", sorted.entries[2].sort_key)
      assert.equals("b", sorted.entries[3].sort_key)
    end)

    -- Cross-field invariant: `u`-dedup must not drop non-movable entries
    -- whose original anchor exceeds the post-dedup count.
    it("preserves non-movable entries when `u` shrinks #entries", function()
      local o = make_outline("object", {
        make_entry("a", 1, { movable = true }),
        make_entry("a", 2, { movable = true }),
        make_entry("b", 3, { movable = true }),
        make_entry("d", 4, { movable = false }),
        make_entry("e", 5, { movable = false }),
      })
      local sorted = policy.sort(o, { flags = { unique = true }, normalize_keys = true })
      -- Survivors: first "a" (anchor 1), "b", non-movable "d" and "e".
      -- "d" and "e" must remain at their anchored positions (relative tail),
      -- not be silently dropped by the dense pack.
      assert.equals(4, #sorted.entries)
      assert.same({ "a", "b", "d", "e" }, keys(sorted))
    end)

    -- Pinned entries (JS spreads, computed keys, Rust `..base`) carry an empty
    -- sort_key. Several can coexist in one container (`{ ...a, x: 1, ...b }`),
    -- so `u` must never treat two non-movable entries as duplicates of each
    -- other — dropping the second would delete it from the buffer.
    it("never deduplicates non-movable entries that share a sort_key", function()
      local o = make_outline("object", {
        make_entry("", 1, { movable = false }),
        make_entry("x", 2, { movable = true }),
        make_entry("", 3, { movable = false }),
      })
      local sorted = policy.sort(o, { flags = { unique = true }, normalize_keys = true })
      assert.equals(3, #sorted.entries)
      assert.equals(0, #sorted.dropped)
    end)

    -- A `fence` pin blocks crossing: movable entries sort only within the
    -- segment between fences, never past one. This protects order-sensitive
    -- pins (JS spread, Ruby `**splat`) whose meaning depends on what sits
    -- before vs. after them.
    it("fences movable entries between fence pins — they never cross one", function()
      local o = make_outline("object", {
        make_entry("z", 1, { movable = true }),
        make_entry("", 2, { movable = false, fence = true }), -- e.g. `**opts`
        make_entry("a", 3, { movable = true }),
      })
      local sorted = policy.sort(o, { flags = {}, normalize_keys = true })
      -- `z` is before the fence, `a` after; each is alone in its segment, so
      -- the order is unchanged rather than `a, fence, z`.
      assert.same({ "z", "", "a" }, keys(sorted))
    end)

    it("sorts each fence-delimited segment independently", function()
      local o = make_outline("object", {
        make_entry("c", 1, { movable = true }),
        make_entry("b", 2, { movable = true }),
        make_entry("", 3, { movable = false, fence = true }),
        make_entry("e", 4, { movable = true }),
        make_entry("d", 5, { movable = true }),
      })
      local sorted = policy.sort(o, { flags = {}, normalize_keys = true })
      -- Left segment {c,b} → {b,c}; right segment {e,d} → {d,e}; fence fixed.
      assert.same({ "b", "c", "", "d", "e" }, keys(sorted))
    end)

    -- A plain pin (no `fence`) holds its slot but is permeable: movable
    -- entries may sort across it, because its position relative to keyed
    -- entries carries no meaning (Lua positional fields, Nix inherit).
    it("lets movable entries sort across a plain (non-fence) pin", function()
      local o = make_outline("object", {
        make_entry("b", 1, { movable = true }),
        make_entry("", 2, { movable = false }), -- plain pin, e.g. Lua `42`
        make_entry("a", 3, { movable = true }),
      })
      local sorted = policy.sort(o, { flags = {}, normalize_keys = true })
      -- `a` and `b` reorder across the pin; the pin stays at slot 2.
      assert.same({ "a", "", "b" }, keys(sorted))
    end)
  end)

  describe("sort — opts.flags contract (Fail Fast)", function()
    -- opts.flags is a required input, not a soft default: silently coercing
    -- a missing flags table to `{}` would let callers ship missing-flags
    -- bugs that surface as wrong sort behavior much later. Raise instead so
    -- the contract violation is loud at the call site.
    it("raises when opts.flags is omitted", function()
      local o = make_outline("object", {
        make_entry("a", 1),
        make_entry("b", 2),
      })
      assert.has_error(function()
        policy.sort(o, { normalize_keys = true })
      end)
    end)
  end)

  describe("apply_selection_overlay (any-overlap rule)", function()
    it("marks entries overlapping the selection movable=true and the rest false", function()
      local entries = {
        make_entry("c", 1, { range = { 0, 1, 0, 4 }, movable = true }),
        make_entry("a", 2, { range = { 0, 6, 0, 9 }, movable = true }),
        make_entry("b", 3, { range = { 0, 11, 0, 14 }, movable = true }),
      }
      local o = make_outline("object", entries)

      local overlaid = policy.apply_selection_overlay(o, { 0, 1, 0, 9 })

      assert.is_true(overlaid.entries[1].movable)
      assert.is_true(overlaid.entries[2].movable)
      assert.is_false(overlaid.entries[3].movable)
    end)

    it("returns a new Outline without mutating the input movable flags", function()
      local entries = {
        make_entry("c", 1, { range = { 0, 1, 0, 4 }, movable = true }),
        make_entry("b", 2, { range = { 0, 11, 0, 14 }, movable = true }),
      }
      local o = make_outline("object", entries)
      policy.apply_selection_overlay(o, { 0, 1, 0, 4 })
      assert.is_true(entries[1].movable)
      assert.is_true(entries[2].movable)
    end)

    it(
      "preserves each entry's data_range so the applier can still locate trailing-comment boundaries",
      function()
        -- comment_attach assigns data_range to record where the entry's data
        -- ends and an absorbed trailing comment begins. apply_selection_overlay
        -- runs AFTER the builder (which delegates to comment_attach), so it
        -- inherits entries that carry data_range. Dropping it forces the
        -- applier into its no-suffix fallback (data_length == #piece) and
        -- separator_normalize then splices the inter-entry separator AFTER an
        -- absorbed line-comment instead of before it.
        local entry = make_entry("a", 1, { range = { 0, 1, 1, 10 }, movable = true })
        entry.data_range = { 0, 1, 0, 4 }
        local o = make_outline("object", { entry })

        local overlaid = policy.apply_selection_overlay(o, { 0, 0, 5, 0 })

        assert.same({ 0, 1, 0, 4 }, overlaid.entries[1].data_range)
      end
    )
  end)
end)
