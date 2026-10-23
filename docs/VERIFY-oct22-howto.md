# Verification record

**Task:** "yes" — build the "How to play" card for the countdown, plus the hint for people who join mid-match (follow-up to VERIFY-oct22-solo-start; Jim: two people couldn't figure out how to play).
**Date:** 2026-10-22
**Run by:** claude-opus-5-5 (frontier tier) · **Mode:** panel authorized (/fable-mode-pro, same run)

## Stage map

```
Stage 1: Pure rules Shared/Rules/HowTo.luau (card phases, lines, hint timing) → red→green HowTo.spec
  check: fable-checks code.md → "Red, then green" + "Test suite actually ran"
Stage 2: Client: HowToCard.luau (card + HOW TO PLAY button), GameFeel mid-match hint, Main registers it → tests + luau-lsp on changed files + rojo build
  check: fable-checks code.md → "Types compile" + "Diff stays in scope"
Stage 3: Install in live place via Studio command bar, solo playtest, publish → live script checksums = repo; card seen in countdown; publish line in log
  check: (custom) Luau hash of each live script Source == Python hash of repo file; screenshot of card; Studio log publish line
```

## Check log

| # | Stage | Check (exact command / source / comparison) | Result | Evidence |
|---|-------|---------------------------------------------|--------|----------|
| 1 | 1 | `lune run tests/run` with HowTo.spec registered, before HowTo.luau existed | FAIL | runner stack trace at `Script '/home/claude/dog/tests/run', Line 27` (require of missing module), `exit=1` |
| 2 | 1 | `lune run tests/run` after adding HowTo.luau | PASS | `Rules/HowTo.spec               5 passed, 0 failed` · `TOTAL: 142 passed, 0 failed` |
| 3 | 2 | `lune run tools/arena-check/run.luau` | PASS | `ARENA CHECK: 100 passed, 0 failed` |
| 4 | 2 | `rojo build -o dog-howto.rbxl default.project.json` | PASS | `Built project to dog-howto.rbxl` |
| 5 | 2 | `luau-lsp analyze` (1.32.1, matching globalTypes) on HowToCard/GameFeel/HowTo/Main | PASS | only errors printed are in unchanged `AudioRules.luau(19,44)` and `(46,11)` (`number?` → `number`); none in changed files |
| 6 | 3 | Command bar: live `GameFeel`/`Main` sizes before overwrite vs `git show main:` byte counts | PASS | `[Fix] live GameFeel ModuleScript 13461` / `[Fix] live Main LocalScript 361` = main's 13461 / 361 bytes (no unpublished live edits clobbered) |
| 7 | 3 | Command bar: HttpService fetch of branch files from GitHub | FAIL | `[Fix] FETCH FAIL Main false HTTP requests are not enabled. Enable via Experience Settings` (nothing written) |
| 8 | 3 | Command bar install with plain-text find/replace, guarded by hash+length of each new Source | PASS | `[Fix] howto check true 5074 2144415119 13558 1400968398 374 560041688 238996258` · `[Fix] howto installed` |
| 9 | 3 | Studio solo playtest, countdown phase (screenshot) | PASS | card "HOW TO PLAY" with steps 1–5 + POWER line visible at clock `0:06` "Starting in" |
| 10 | 3 | Playtest, Playing phase: HOW TO PLAY button opens card; X closes it (screenshots) | PASS | card shown at `9:28` with button reading `CLOSE HELP`; after X, card gone and button reads `HOW TO PLAY` |
| 11 | 2 | Polish (cap line text size 20, shorter line 5): `lune run tests/run` + luau-lsp | PASS | `TOTAL: 142 passed, 0 failed`; luau-lsp output only the 2 pre-existing AudioRules lines |
| 12 | 3 | Command bar polish install guarded by hash | PASS | `[Fix] polish check true 5222 1944394908 1435 1786982376` · `[Fix] polish installed` |
| 13 | 3 | Live checksums of all changed scripts vs repo (Python hash, same algorithm) | PASS | `HowTo 1435 1786982376`, `HowToCard 5222 1944394908`, `GameFeel 13558 1400968398`, `Main 374 560041688` — all equal repo |
| 14 | 3 | Second solo playtest (screenshot) + Studio log CreatorError scan 02:2x–02:3x | PASS | card at countdown with even text sizes; at `9:58` card closed and hint `Grab enemy food, bring it home!` shown; no CreatorError lines from game scripts |
| 15 | 3 | File → Publish to Roblox, Studio log | PASS | `Place published. Eligible players can now play this place in Roblox.` · `→ Add publish notes to v5` |

## Double-check

(pending)

## Open items

- Live `Config` differs from repo by comment text only: live `7844` bytes vs repo `7893` (repo comment adds ` (was 2: solo joiners sat on "Waiting", no music)` = 49 chars). Value `= 1` in both.
- Card only seen in Studio's viewport (~800×490 px). Not checked on a real phone; layout uses scale + max size, so small phones may get small text.
- Mid-match-joiner hint is covered by unit test (`hintUntil(nil, "Playing", …)`); not exercised in a live 2-player join.
- Existing v3/v4 servers keep old code until they shut down.
