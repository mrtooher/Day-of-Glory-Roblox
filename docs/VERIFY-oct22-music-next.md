# Verification record

**Task:** "the music still doesnt play when the first song ends"
**Date:** 2026-10-22
**Run by:** claude-opus-5-5 (frontier tier) · **Mode:** panel authorized (/fable-mode-pro, same session)

## Stage map

```
Stage 1: Reproduce in Studio solo playtest (client command bar: jump song 1 to its end) → logged stuck state
  check: (custom) client log shows next SoundId set but IsPlaying false / TimePosition 0.0 for several seconds
Stage 2: Fix Audio.luau (start next song after Ended returns; restart a loaded-but-stuck track) → tests + luau-lsp no new errors
  check: fable-checks code.md → "Test suite actually ran" + "Types compile" (compare against main's errors)
Stage 3: Install in live place (hash-guarded), repeat the same repro for 2 song changes, publish → playing true after each change; publish line
  check: (custom) same repro script, before = FAIL row, after = PASS row
```

## Check log

| # | Stage | Check (exact command / source / comparison) | Result | Evidence |
|---|-------|---------------------------------------------|--------|----------|
| 1 | 1 | Studio solo test, client command bar: `m.TimePosition=m.TimeLength-3`, print state each second (live v6 code) | FAIL | `[Audio] Now playing Feast for your life (140350912499061)` then `t+4 ... 0.0/62.7 playing false loaded true vol 0.50` through `t+9 ... 0.0/62.7 playing false` |
| 2 | 1 | Same session: call `m:Play()` from command bar (outside the Ended event) | PASS | `[Dbg] replay t+3 rbxassetid://140350912499061 3.0/62.7 playing true` — Play works when not called inside Ended |
| 3 | 1 | Search all Studio logs for load failures | PASS | no `Could not load` / sound-fail lines (0 matches besides an old command echo) |
| 4 | 2 | `lune run tests/run` | PASS | `TOTAL: 142 passed, 0 failed` |
| 5 | 2 | `luau-lsp analyze` Audio.luau, branch vs main | PASS | same 5 pre-existing errors on both (lines 54–56 `TextLabel?`, 75 and 141→147 `string?`); none new |
| 6 | 3 | Command bar install guarded by hash of live Source before (= main) and after (= branch) | PASS | `[Fix] audio check true 8384 1831450116 8920 1059536320` · `[Fix] audio installed 8920 1059536320` |
| 7 | 3 | Same repro, two rounds (song 1 end → song 2; song 2 end → song 1) | PASS | `[Audio] Now playing Feast for your life` → `round1 t+3 ... 0.5/62.7 playing true`; `[Audio] Now playing Neon Horizon` → `round2 t+3 ... 0.9/340.0 playing true` |
| 8 | 3 | File → Publish to Roblox | PASS | `→ Add publish notes to v7` |

## Double-check

(pending)

## Open items

- Cause inferred from Roblox behaviour seen in Studio (Play() inside the same Sound's Ended event does nothing); not documented by Roblox that I checked.
- Tested by jumping to the end of each song, not by listening through a full song; live servers not tested.
- Song lengths seen: Neon Horizon 340.0 s, Feast for your life 62.7 s.
- Servers started before v7 keep the old music code until they shut down.
