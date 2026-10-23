# Verification record

**Task:** "change it to one player required and let's look through everything" — also: no music heard when the game starts; two people couldn't figure out how to play.
**Date:** 2026-10-22
**Run by:** claude-opus-5-5 (frontier tier) · **Mode:** panel authorized (/fable-mode-pro by name)

## Stage map

```
Stage 1: Repo change MinHumansToStart 2 -> 1 (red→green test) → tests 137/0, arena-check 100/0, branch fix/solo-start pushed
  check: fable-checks code.md → "Red, then green" + "Test suite actually ran" + "Diff stays in scope"
Stage 2: Root-cause music + how-to-play reports from code and logs → cited file/line findings
  check: (custom) each finding quotes the code line or log line it rests on
Stage 3: Apply to live game in Studio (open cloud place, edit Config, solo playtest, publish) → [Audio] Now playing in solo playtest log; Studio publish confirmed
  check: (custom) Studio log shows Phase leaves Waiting with 1 player and "[Audio] Now playing"
```

## Check log

| # | Stage | Check (exact command / source / comparison) | Result | Evidence |
|---|-------|---------------------------------------------|--------|----------|
| 1 | 1 | `lune run tests/run` (baseline, main 602a0f2) | PASS | `TOTAL: 136 passed, 0 failed` |
| 2 | 1 | `lune run tests/run` with new test, before fix | FAIL | `FAIL Rules/MatchPhase.spec > one human alone starts a match vs bots (Jim 2026-10-22): ... expected "Intermission", got "Waiting"` |
| 3 | 1 | `lune run tests/run` after `Config.MinHumansToStart = 1` | PASS | `TOTAL: 137 passed, 0 failed` |
| 4 | 1 | `lune run tools/arena-check/run.luau` | PASS | `ARENA CHECK: 100 passed, 0 failed` |
| 5 | 1 | `rojo build -o dog-solo.rbxl default.project.json` | PASS | `Built project to dog-solo.rbxl` |
| 6 | 1 | `git diff --stat` vs stage map | PASS | `src/shared/Config.luau 2 +-`, `tests/Rules/MatchPhase.spec.luau 8 ++++++++` |
| 7 | 1 | `git ls-remote origin fix/solo-start` | PASS | `40fcc22a... refs/heads/fix/solo-start` (stale: branch later advanced to the VERIFY commits) |
| 8 | 2 | `src/shared/Config.luau` Audio.musicPhases | PASS | `musicPhases = { "Intermission", "Playing" }` — no music in Waiting |
| 9 | 2 | `src/client/Hud.luau` phaseText / `PowerButtons.luau` | PASS | `Waiting = "Waiting for players"`, `button.Text = "WAIT FOR MATCH"` — a solo player in Waiting sees only these labels and a `--:--` clock (wording corrected after double-check: original said "sees nothing to do") |
| 10 | 3 | Studio open of place 110189125329460 (Studio log 20261023T021705Z) | FAIL | `GetPlaceInfoFailure with code 401, message {"errors":[{"code":9002,"subcode":1,"message":"User is not authenticated"}]}` |
| 11 | 3 | Jim logged in; Studio open of place, command bar `print(... MinHumansToStart ..., game.PlaceId)` | PASS | `[Fix] before: Config.MinHumansToStart = 2 place 110189125329460` |
| 12 | 3 | Command bar gsub on `Shared.Config.Source` (anchored on `Config%.MinHumansToStart = 2\n`, must match once) | PASS | `[Fix] replaced 1 after: Config.MinHumansToStart = 1` |
| 13 | 3 | Studio Test (solo, 1 client) → Studio log + client view | PASS | `[Audio] Now playing Neon Horizon (89048811438062)`; HUD shows `9:33` / `Bring food home!` (phase Playing with 1 human) |
| 14 | 3 | After Stop, edit-mode re-check of Config source | PASS | `[Fix] edit-mode check: Config.MinHumansToStart = 1 false` |
| 15 | 3 | File → Publish to Roblox, Studio log | PASS | `Place published. Eligible players can now play this place in Roblox.` / `→ Add publish notes to v4` |
| 16 | 3 | Same Studio log, solo playtest window 02:21:00–02:21:55 | PASS | `[Food] Bot 7 grabbed PIZZA PALACE's burger!` at 02:21:53 — bots only act in Playing, so 1 human reached Playing (logged late, found by double-check) |

## Double-check

```
Double-check: 15 claims + 6 requirements.
PASS: 15 claims, R1–R3 PASS. FIXED after FAIL: 4 seam items in this record (overstated check 9 wording; "Stage 3 will observe it" open item was false; root cause stated as observed when inferred; HUD reading in check 13 not in log). Partial: R4, R5 (see Open items). UNVERIFIABLE: live music on Roblox servers; checks 1-5 by the Sonnet checker (no lune there; Haiku re-ran them: 137/0, 100/0).
Checkers: 1x Haiku (mechanical, 15/15 CONFIRMED), 1x Sonnet (requirements + seam), 0 re-check rounds (fixes are wording in this file)
```

- Fixed: check 9 said "solo player sees nothing to do" → now states only the labels shown.
- Fixed: Open items said the Stage 3 playtest "will observe" the no-music cause → it ran with the fix applied, so pre-fix silence stays inferred.
- Fixed: Stage-1 commit message states solo joiners "sat on Waiting forever with no music" as fact → recorded here as inference (commit message itself not rewritten).
- Fixed: check 13's HUD values come from a screenshot, not the log → bot-grab line added as log evidence (row 16).

## Open items

- Studio 401 (check 10) resolved: Jim logged in 22:20 ET; checks 11–15 ran after.
- Root cause of both reports is INFERRED from code, not observed: live player logs have no game script output. If the two people played together, the old 2-player minimum would not have blocked them, and the how-to-play gaps below are the likelier cause.
- Live music not verified on Roblox servers; only "Neon Horizon" was heard to start (Studio). "Feast for your life" (140350912499061) not exercised this run.
- How-to-play gaps remain (GameFeel.luau): start hint shows only 12 s (`HINT_SECONDS = 12`); players who join mid-match never get the hint; no on-screen mention of the power key (Q); Intermission (15 s) has no controls/how-to panel.
- Servers already running v3 keep the 2-player rule until they shut down (Roblox does not hot-swap code).
