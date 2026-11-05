# Verification record

**Task:** "can we move the jump button off of the power button. They are right on top of each other. Also, can we make the water a little deeper? It doesnt flicker on the screen but it also doesnt do anything like get any deeper. so theres no swimming, no puddles, no slowdown at all. ... let me know if you have any ideas to spice up, improve the game." (/fable-checks-games /fable-mode-pro)
**Date:** 2026-11-04
**Run by:** claude-opus-5-5 (frontier tier) · **Mode:** panel authorized (/fable-mode-pro by name)
**Skills loaded:** fable-mode-pro v1.2, fable-checks-games v1.2.1, fable-mode **v6.1** (no step 0 in that version; step 0 run from Pro's own rules), fable-checks, fable-audit, execution-guardrails. No LANDMINES.md in this repo.

## Stage map

```
Decision: which button moves → POWER moves above Roblox's jump button, follows it on rotate (user)
Decision: what the water does → knee-deep wading, same floor, slows walkers, splashes (user)
Decision: food carriers in water → same slow as everyone (user)
Decision: wade speed → 70% of normal, Config.Map.water.speedMultiplier (assumed)
Decision: depth → water top 1.2 studs above the sand, Config.Map.water.depth (assumed)
Decision: wading vs power slows → counts as a slow: strongest slow wins (pizza/slow-mo don't stack with water); carrier 0.75 still multiplies on top (assumed)
Decision: splash → client particles only, no sound (Config.Audio has no splash id) (assumed)

Stage 1: Shared/Rules/Wading (pure) + Config.Map.water zones + Movement terrain slow → tests green
  check: fable-checks-games → "Roblox: Lune tests" with red-then-green (spec first)
Stage 2: MapWater draws knee-deep water from Config.Map.water; floating props lifted; islands terraced; docks raised; sign text → arena-check Water + City pass; every water part's footprint matches a Config zone
  check: fable-checks-games → "Roblox: offline map or world checks" + (custom) zone-vs-part footprint check added to arena-check, red first
Stage 3: StatusService applies the wade slow in the Water arena and sets a Wading attribute → type check, tests
  check: fable-checks-games → "Roblox: type check" (no new errors vs main) + Lune tests
Stage 4: Client: POWER button sits above the touch jump button; Splash module → type check, rojo build
  check: fable-checks-games → "Roblox: type check" + (custom) `rojo build` succeeds
Stage 5: Push branch + PR; playtest script for Jim (Studio, phone emulator + Water arena)
  check: fable-checks-games → "Playtest script" (rows from Jim's report only)
Stage 6: Double-check gate
```

## Check log

| # | Stage | Check (exact command / source / comparison) | Result | Evidence |
|---|-------|---------------------------------------------|--------|----------|
| 0 | — | Baseline on `main` b40e866: `lune run tests/run`; `lune run tools/arena-check/run Water`; `... City` | PASS | `TOTAL: 151 passed, 0 failed` · `Water arena: 3690 parts, 8 dash pads, 4 jump pads, 70 signs` · `ARENA CHECK: 105 passed, 0 failed` (both) |
| 1 | — | Baseline type check on `main`: `rojo sourcemap` + `luau-lsp analyze` (1.53.1, globalTypes 1.53.1) on `src` | PASS | `exit=0`, 0 lines |
| 2 | — | Type checker can fail: probe file with `p.Sizee` on a Part and `h.WalkSpeeed` on a Humanoid (deleted after) | PASS | `TypeError: Key 'Sizee' not found in class 'Part'` · `TypeError: Key 'WalkSpeeed' not found in class 'Humanoid'` |
| 3 | 1 | `lune run tests/run` with `Rules/Wading.spec` registered, before `Rules/Wading.luau` existed | FAIL | stack trace ending `Script '/home/claude/gamerepos/mrtooher_Day-of-Glory-Roblox/tests/run', Line 29` · `exit=1` |
| 4 | 1 | `lune run tests/run` after `Rules/Wading.luau`, `Movement.terrainSlow`, `Config.Map.water` | PASS | `Rules/Wading.spec 13 passed, 0 failed` · `Rules/Movement.spec 9 passed, 0 failed` · `TOTAL: 164 passed, 0 failed` · `exit=0` |
| 5 | 2 | New Water checks in `tools/arena-check/run.luau` (water top = depth, bottoms clear bed, parts inside zones, zones fully drawn, islands/docks above water, floating props at surface), run before any map change: `lune run tools/arena-check/run Water` | FAIL | `FAIL every water part's top at depth 1.2 (15 off)` · `FAIL zone 1 fully drawn (water 4300.0 vs zone 4204.0)` · `FAIL island 1 has a collidable top at or above the water (top -inf)` · `FAIL 4 collidable docks above the water (4 docks, 4 low)` · `FAIL floating props sit at the surface (21 sunk)` · `ARENA CHECK: 113 passed, 8 failed` · `exit=1` (red as intended; the zone 1/2 area mismatch also exposed a config error: dock rectangles were listed as holes but water stays drawn under docks → docks moved to their own `docks` list) |
| 6 | 1 | `lune run tests/run` after the docks split (new "a dock is dry" test, 4 docks in Config) | PASS | `Rules/Wading.spec 14 passed, 0 failed` · `TOTAL: 165 passed, 0 failed` · `exit=0` |
| 7 | 2 | `lune run tools/arena-check/run Water` after MapWater: knee-deep `deepWater` blocks (0.08 → depth), foam/ripples/rings/buoys/boats/ducks at the surface, islands lifted on stepped solid bases, docks raised with a shore step, canal rims at the waterline, sign "KNEE DEEP!" | PASS | `Water arena: 3700 parts, 8 dash pads, 4 jump pads, 70 signs` · `ARENA CHECK: 121 passed, 0 failed` · `exit=0` (all 105 earlier gameplay checks still pass + 16 new water checks) |
| 8 | 2 | (custom) Lune probe of NorthIsland after the lift: every part's CFrame centre Y, and count of parts reset to the XZ origin (Lune keeps CFrame/Position separate) | PASS | `IslandSand ... centreY 1.28` (was 0.08) · `Starfish ... 1.47` · `PalmTrunkBase ... 2.90..3.15` · `atXZorigin=0` for all 28 part names |
| 9 | 2 | `lune run tools/arena-check/run City` (City theme must be untouched) + `lune run tests/run` | PASS | `City arena: 2416 parts, 8 dash pads, 4 jump pads, 61 signs` (same as baseline) · `ARENA CHECK: 105 passed, 0 failed` · `TOTAL: 165 passed, 0 failed` |
| 10 | 3 | `luau-lsp analyze` (1.53.1) after StatusService wading (MapService via init, `Wading.step` per tick, `Wading` model attribute, `terrainSlow` into Movement) | FAIL | `src/shared/Rules/Wading.luau(49,14): TypeError: Cannot call a value of type {Rect} in union: {Rect} \| {\|  \|}` · `exit=1` |
| 11 | 3 | Same `luau-lsp analyze` after typing `local docks: { Rect } = spec.docks or {}`; then `lune run tests/run` | PASS | lsp `exit=0`, 0 lines (main baseline also 0) · `TOTAL: 165 passed, 0 failed` |
| 12 | 4 | `lune run tests/run` with `Rules/PowerLayout.spec` registered, before `Rules/PowerLayout.luau` existed | FAIL | stack trace ending `Script '/home/claude/gamerepos/mrtooher_Day-of-Glory-Roblox/tests/run', Line 30` · `exit=1` |
| 13 | 4 | `lune run tests/run` after `Rules/PowerLayout.luau` (phone, tablet, right-edge clamp, top-edge fallback to the left, no jump button) | PASS | `Rules/PowerLayout.spec 5 passed, 0 failed` · `TOTAL: 170 passed, 0 failed` · `exit=0` |
| 14 | 4 | `luau-lsp analyze` after PowerButtons `keepClearOfJump` + new `client/Splash.luau` + Main boot list | FAIL | `src/client/PowerButtons.luau(63,57): TypeError: Key 'TouchGui' not found in class 'PlayerGui'` · `exit=1` |
| 15 | 4 | Same `luau-lsp analyze` after `FindFirstChild("TouchGui")`; `rojo build default.project.json -o /tmp/dog-test.rbxl`; `lune run tests/run` | PASS | lsp `exit=0`, 0 lines · `Built project to dog-test.rbxl` `exit=0` · `TOTAL: 170 passed, 0 failed` |
| 16 | 4 | (custom) Lune `deserializePlace` on the built place: new/changed modules present at their Rojo paths | PASS | `Shared.Rules.Wading ModuleScript 2372` · `Shared.Rules.PowerLayout ModuleScript 1267` · `Client.Splash ModuleScript 2848` · `Client.PowerButtons ModuleScript 6606` · `Services.StatusService ModuleScript 4248` · `5/5 found` |

## Double-check

(pending)

## Open items

- Assumed decisions above (70% speed, 1.2-stud depth, slows don't stack, no splash sound) — Jim to confirm in playtest.
