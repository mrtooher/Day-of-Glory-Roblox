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
| 7 | 1 | `git ls-remote origin fix/solo-start` | PASS | `40fcc22a... refs/heads/fix/solo-start` |
| 8 | 2 | `src/shared/Config.luau` Audio.musicPhases | PASS | `musicPhases = { "Intermission", "Playing" }` — no music in Waiting |
| 9 | 2 | `src/client/Hud.luau` phaseText / `PowerButtons.luau` | PASS | `Waiting = "Waiting for players"`, `button.Text = "WAIT FOR MATCH"` — solo player sees nothing to do |
| 10 | 3 | Studio open of place 110189125329460 (Studio log 20261023T021705Z) | FAIL | `GetPlaceInfoFailure with code 401, message {"errors":[{"code":9002,"subcode":1,"message":"User is not authenticated"}]}` |

## Double-check

(pending)

## Open items

- Studio signed out (401). Jim must log in before the live game can be edited/published.
- Live player logs don't contain game script output, so "no music on live server" root cause is inferred from code (Waiting phase has no music), not observed. Stage 3 playtest will observe it.
