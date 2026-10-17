# Verification record

**Task:** "Build the code for a Roblox game as a Rojo project in this repo. Language: Luau." (Day of Glory food capture-the-flag brief, `roblox-claude-code-brief.md`)
**Date:** 2026-10-17
**Run by:** Claude Code cloud session (Opus tier) · **Mode:** panel (Fable Mode Pro invoked by name)

## Stage map

```
Stage 1: Toolchain + Rojo scaffold → lune/rojo/luau-lsp binaries run; default.project.json builds
Stage 2: Roblox API source check → every engine API used is found in the official API dump / creator-docs source
Stage 3: Pure Rules modules + Lune tests → tests/run.luau passes, each rule red-then-green, error paths covered
Stage 4: Power modules (PowerBase cooldown class + 8 powers, pure via ctx) + tests → same runner passes
Stage 5: Server services (Match, Food, Tag, Power, Bot, Map, Actors) → luau-lsp analyze with Roblox defs + sourcemap: 0 errors; rojo build exit 0
Stage 6: Client scripts (power buttons, HUD, character select) → same analyze + build checks
Stage 7: README (rojo serve, test command, Studio-only list) → read back against brief
Stage 8: Commit, push, draft PR → git log / push output / PR URL
```

Stage checks:
- Stage 1: fable-checks code.md → "Test suite actually ran" (tool `--version` output) + `rojo build` exit 0 (custom)
- Stage 2: (custom) query `Full-API-Dump.json` (MaximumADHD/Roblox-Client-Tracker) per member; `Deprecated` tag ⇒ use preferred replacement
- Stage 3/4: fable-checks code.md → "Test suite actually ran and passed", "Red, then green", "Error path exercised"
- Stage 5/6: fable-checks code.md → "Types compile" (`luau-lsp analyze --definitions globalTypes.d.luau --sourcemap sourcemap.json`)
- Stage 7: fable-checks documents.md → read-back against spec
- Stage 8: fable-checks code.md → "Diff stays in scope"

## Check log

| # | Stage | Check (exact command / source / comparison) | Result | Evidence |
|---|-------|---------------------------------------------|--------|----------|
| 1 | 1 | `lune --version`; `rojo --version`; `luau-lsp --version` (logged late) | PASS | `lune 0.10.4` / `Rojo 7.4.4` / `1.53.1` |
| 2 | 2 | WebFetch `create.roblox.com/docs/...` (logged late) | UNVERIFIABLE | `getaddrinfo ENOTFOUND create.roblox.com`; curl: `CONNECT tunnel failed, response 403` (network policy). Fallback: Roblox/creator-docs GitHub source + API dump |
| 3 | 2 | `q.py Full-API-Dump.json <members>` — first batch (logged late) | FAIL | `Player.LoadCharacter ... 'Deprecated', {'PreferredDescriptorName': 'LoadCharacterAsync'}`; `Players.CreateHumanoidModelFromDescription ... 'Deprecated'`; `BodyVelocity ['Deprecated' ... 'LinearVelocity']` → code must use `LoadCharacterAsync`, `CreateHumanoidModelFromDescriptionAsync`, no BodyVelocity |
| 4 | 2 | same script, replacements (logged late) | PASS | `Player.LoadCharacterAsync [Player] Function () tags=['Yields']`; `Players.CreateHumanoidModelFromDescriptionAsync ... tags=['Yields']` |

| 5 | 1 | `rojo build default.project.json -o test.rbxl; echo "exit=$?"` | PASS | `Built project to test.rbxl` / `exit=0` |
| 6 | 3 | `lune run tests/run; echo "exit=$?"` before Rules modules existed (red) | FAIL | `error requiring module "../../src/shared/Rules/Scoring": could not resolve child component "Scoring"` / `exit=1` |
| 7 | 3 | `lune run tests/run; echo "exit=$?"` after Rules modules (green) | PASS | `TOTAL: 81 passed, 0 failed` / `exit=0` |

## Double-check

_(pending)_

## Open items

_(pending)_
