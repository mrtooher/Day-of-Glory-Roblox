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
| 6 | 3 | Command bar: live `GameFeel`/`Main` sizes before overwrite vs `git show main:` byte counts | PASS | `[Fix] live GameFeel ModuleScript 13461` / `[Fix] live Main LocalScript 361` = main's 13461 / 361 bytes (length match only — content not compared; wording corrected after double-check) |
| 7 | 3 | Command bar: HttpService fetch of branch files from GitHub | FAIL | `[Fix] FETCH FAIL Main false HTTP requests are not enabled. Enable via Experience Settings` (nothing written) |
| 8 | 3 | Command bar install with plain-text find/replace, guarded by hash+length of each new Source | PASS | `[Fix] howto check true 5074 2144415119 13558 1400968398 374 560041688 238996258` · `[Fix] howto installed` |
| 9 | 3 | Studio solo playtest, countdown phase (screenshot) | PASS | card "HOW TO PLAY" with steps 1–5 + POWER line visible at clock `0:06` "Starting in" |
| 10 | 3 | Playtest, Playing phase: HOW TO PLAY button opens card; X closes it (screenshots) | PASS | card shown at `9:28` with button reading `CLOSE HELP`; after X, card gone and button reads `HOW TO PLAY` |
| 11 | 2 | Polish (cap line text size 20, shorter line 5): `lune run tests/run` + luau-lsp | PASS | `TOTAL: 142 passed, 0 failed`; luau-lsp output only the 2 pre-existing AudioRules lines |
| 12 | 3 | Command bar polish install guarded by hash | PASS | `[Fix] polish check true 5222 1944394908 1435 1786982376` · `[Fix] polish installed` |
| 13 | 3 | Live checksums of all changed scripts vs repo (Python hash, same algorithm) | PASS | `HowTo 1435 1786982376`, `HowToCard 5222 1944394908`, `GameFeel 13558 1400968398`, `Main 374 560041688` — all equal repo |
| 14 | 3 | Second solo playtest (screenshot) + Studio log CreatorError scan 02:2x–02:3x | PASS | card at countdown, short lines no longer oversized (Studio viewport ~800×490 only); at `9:58` card closed and hint `Grab enemy food, bring it home!` shown; no CreatorError lines from game scripts |
| 15 | 3 | File → Publish to Roblox, Studio log | PASS | `Place published. Eligible players can now play this place in Roblox.` · `→ Add publish notes to v5` |
| 16 | 1 | Double-check (Sonnet) R3f: card line "tap the big yellow button" vs PowerButtons.luau during Waiting/Intermission | FAIL | `button.Text = "WAIT FOR MATCH"`, `BackgroundColor3 = Color3.fromRGB(100,100,100)` — grey while the card is open |
| 17 | 1 | Fixed line → `lune run tests/run` | PASS | `TOTAL: 142 passed, 0 failed`; HowTo.luau `1467` bytes, hash `1320796594` |
| 18 | 3 | Command bar install guarded by hash; solo playtest screenshot at countdown | PASS | `[Fix] power line installed 1467 1320796594`; card shows `POWER: when the match starts, tap your power button (bottom right) or press Q.` at `0:09` |
| 19 | 3 | File → Publish to Roblox; CreatorError scan 02:3x | PASS | `→ Add publish notes to v6`; `0` game-script CreatorError lines |

## Double-check

```
Double-check: 11 claims + 6 requirements.
PASS: 11 claims (Haiku, all CONFIRMED), R1 R2 R4 R5 R6 PASS (R4: no overlap among bottom-left buttons). FIXED after FAIL: 1 — R3f card POWER line described a "big yellow button" that is grey "WAIT FOR MATCH" while the card is open. Seam fixes: 2 wordings in this record (row 6 "no edits clobbered" → length-only; row 14 "even text sizes" → viewport-limited). UNVERIFIABLE: real-phone layout.
Checkers: 1x Haiku (mechanical), 1x Sonnet (requirements + seam), fix re-checked by test + hash + screenshot (rows 17–19), no re-check spawn
```

- Fixed: card line 6 → now "POWER: when the match starts, tap your power button (bottom right) or press Q." (repo + live v6).
- Fixed: row 6 evidence overstated (length match only).
- Fixed: row 14 "even text sizes" limited to the Studio viewport.
- Confirmed by Haiku: live Config = repo Config minus the 49-byte comment (`7844` / `199450193` reproduced by removing it).

## Open items

- Live `Config` = repo Config minus a 49-byte comment (Haiku reproduced live hash `199450193` by removing it). Value `= 1` in both.
- Narrow screens: HOW TO PLAY button spans x 290–410 from the left; the power button is 120 px wide, 20 px from the right. They overlap below ~550 px width and HOW TO PLAY clips below 410 px. Landscape phones are usually wider; not checked on a real phone.
- Card text simplifies two rules: any enemy on your side can be tagged (not only raiders) and a tagged player is sent home; the 10-minute time limit is not mentioned.
- Mid-match-joiner hint covered by unit test only; not exercised with a real second player joining.
- Servers started before v6 keep old code until they shut down.
