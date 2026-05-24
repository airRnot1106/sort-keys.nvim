# sort-keys.nvim — VHS demo tape
#
# Generates vhs/demo.gif via `nix run .#vhs` (preferred) or by calling
# `vhs vhs/demo.tape` directly with vhs + nvim + ttyd + ffmpeg on PATH.
#
# Covers four scenarios on a single JSON fixture:
#   1. :SortKeys           — ascending sort of the top-level keys
#   2. :SortKeys!          — descending sort (! flag = reverse)
#   3. :DeepSortKeys       — recurse into nested containers
#   4. Visual line + :SortKeys — partial sort of just the selected range

Output vhs/demo.gif

Require nvim

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 600
Set Padding 20
Set TypingSpeed 50ms
Set PlaybackSpeed 1.0

# ─── boot ─────────────────────────────────────────────────────────────────────
# Hide the shell prompt + launch line so the recording opens directly on
# the nvim buffer (the literal `\[ \]` bracket escapes leaked by
# non-interactive bash's PS1 look like garbage in the gif).
Hide
Type "nvim -u vhs/init.lua vhs/fixture.json"
Enter
Sleep 2s
Show

# ─── 1. :SortKeys (ascending top-level) ───────────────────────────────────────
Type ":SortKeys"
Enter
Sleep 2s

# Undo to restore the original order for the next scenario.
Type "u"
Sleep 1s

# ─── 2. :SortKeys! (descending) ───────────────────────────────────────────────
Type ":SortKeys!"
Enter
Sleep 2s

Type "u"
Sleep 1s

# ─── 3. :DeepSortKeys (recurse into nested containers) ────────────────────────
Type ":DeepSortKeys"
Enter
Sleep 2s

Type "u"
Sleep 1s

# ─── 4. Visual range + :SortKeys (partial sort) ───────────────────────────────
# Use a structural motion instead of fixed row offsets so the tape survives
# fixture edits:
#   /colors   — jump to the "colors" key
#   f{        — move to the opening brace of its value
#   vi{       — select the inner contents of that object
# Then :SortKeys (visual cmdline auto-prefixes :'<,'>) sorts only the
# entries inside that selection.
Type "gg"
Sleep 300ms
Type "/colors"
Enter
Sleep 500ms
Type "f{"
Sleep 300ms
Type "V"
Sleep 300ms
Type "8j"
Sleep 500ms
Type ":SortKeys"
Enter
Sleep 2s

# ─── teardown ─────────────────────────────────────────────────────────────────
# End on a truly blank frame so the gif loop has a visible seam between
# the final SortKeys result and the first frame of the next playback.
# Trick: quit nvim while hidden, run `clear && sleep` to wedge the shell
# inside a delay (the prompt cannot reappear), then briefly Show the
# resulting empty screen.
Hide
Type ":q!"
Enter
Sleep 200ms
Type "clear && sleep 5"
Enter
Sleep 100ms
Show
Sleep 600ms
