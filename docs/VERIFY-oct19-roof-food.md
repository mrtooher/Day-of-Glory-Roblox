# Verification record

**Task:** "Let's move the food though. have two at the base and two other items at the nearest buildings on top. Also make the lettering smaller or just create a beacon noise when they are nearby food. I like the line, but the annoucement of where to go takes up to much of the screen. … Any building improvements feel free to make as well. Or suggestions for qwen to code for us to save some usage." (Jim, 2026-10-19 18:44 ET, `/fable-mode-pro`; also: "merge and commit")
**Date:** 2026-10-19
**Run by:** claude-opus-5-5 (orchestrator) · **Mode:** panel (spawn authorized by `/fable-mode-pro`)

## Before planning

- PR #13 merged on request: `gh api -X PUT .../pulls/13/merge` → `true 63543ff Pull Request successfully merged`. Branch `feat/food-on-roofs` from `origin/main` 63543ff.
- Built-in sounds (Mac `content/sounds/`): 11 files; beacon uses `rbxasset://sounds/volume_slider.ogg` (+ `Config.Audio.sfx.beacon` slot for a custom id).
- Layout decision (Jim: "two at the base and two other items at the nearest buildings on top"): per team, Pizza + Taco stay at the base counter; Sushi + Burger go on the roofs of the two buildings nearest that base: Red → Sushi Bar (-120, 50) / Burger Joint (-120, -50); Blue → Sunny Apts (120, 50) / Arcade (120, -50). Each roof gets stairs (bots can't use jump pads).

## Stage map

```
Stage 1: Food layout rules → Config.FoodLayout + pure Rules/FoodLayout (which food where); FoodService spawns base slots + roof slots from markers; bots target the nearest AVAILABLE enemy food (not always the counter).
         Check: fable-checks code.md → "Red, then green" (FoodLayout spec) + "Types compile" (luau-lsp).
Stage 2: Arena (worker): roof pedestals <Team>RoofFood1/2, stairs to each of the 4 roofs, building polish.
         Check (custom): tools/arena-check: markers inside the right building footprint, on a roof, headroom; stairs rise ≤ 1.6 per step from ground to roof, headroom above each step; all previous zones still clear.
Stage 3: UI: smaller kitchen markers, small hint pill, smaller banners; beacon ping near reachable enemy food (faster/higher when closer).
         Check: code.md → "Types compile" + pure Rules/Beacon spec (interval vs distance) red→green.
Stage 4: Docs: docs/QWEN-TASKS.md (ready-to-paste prompts) + project handoff update.
         Check (custom): read the files back; each prompt names files, acceptance tests, and "don't touch" list.
Stage 5: Studio smoke (computer use): server log shows a roof-food grab + a base grab; screenshots of a roof pedestal, marker size, hint size; 0 CreatorError.
         Check (custom): log grep + screenshot read. UNVERIFIABLE if Studio can't be driven.
Stage 6: double-check panel.
```

## Check log

| # | Stage | Check (exact command / source / comparison) | Result | Evidence |
|---|-------|---------------------------------------------|--------|----------|
| 1 | 2 | `lune run tools/arena-check/run` with new roof-food + stairs contract, current map (expected RED) | FAIL | `RedRoofFood1 exists and is collidable` FAIL … `ARENA CHECK: 60 passed, 12 failed` |
| 2 | 1 | `lune run tests/run` with new `Rules/FoodLayout.spec` before the module exists | FAIL | `error requiring module` (runner aborts) |
| 3 | 1 | same after `Rules/FoodLayout` + `Config.FoodLayout = { base = {Pizza, Taco}, roof = {Sushi, Burger} }` | PASS | `Rules/FoodLayout.spec 4 passed, 0 failed` · `TOTAL: 130 passed, 0 failed` |
| 4 | 1 | `luau-lsp analyze ... src` after FoodService/MapService/BotService wiring (roof slots, `FoodService.available`, bots raid nearest available food) | PASS | `lsp exit=0` · `TOTAL: 130 passed, 0 failed` |
| 5 | 3 | `lune run tests/run`: `Rules/Beacon.spec` vs placeholder module (always silent) | FAIL | `Rules/Beacon.spec 1 passed, 3 failed` (`expected 1, got nil`) |
| 6 | 3 | same with real Beacon (lerp) | FAIL | `expected 0.15, got 0.15000000000000002` (float at endpoint) |
| 7 | 3 | same with exact-endpoint lerp `a*(1-k)+b*k` | PASS | `Rules/Beacon.spec 4 passed, 0 failed` · `TOTAL: 134 passed, 0 failed` |
| 8 | 3 | `luau-lsp analyze ... src` after GameFeel (beacon loop, smaller markers/banners/hint, roof FOOD tags) + Hud (smaller feed, duplicate carry text removed) | PASS | `lsp exit=0` · `TOTAL: 134 passed, 0 failed` |
| 9 | 4 | docs/QWEN-TASKS.md names vs code: `grep` awardPoint / startMatch / endMatch / TagService.tag / Main `order` / PhaseEndsAt / MatchDurationSeconds / PostMatchSeconds / FireServer+pending / Remotes name list | PASS | all found (`MatchService.luau:83,96,114`, `TagService.luau:34`, `Main.server.luau:12`, `Remotes.luau:16` …) |
| 10 | 4 | same: "main colour from Looks.luau", "create it the same way" | FAIL | Looks has no single colour field (`shirt = "#3a2a1a"` hex strings); prompts reworded to `Looks[id].shirt` + `Color3.fromHex`, and the exact Remotes list |
| 11 | 2 | lead re-run after worker: `lune run tools/arena-check/run` | PASS | `arena: 2568 parts, 8 dash pads, 4 jump pads, 61 signs` · `ARENA CHECK: 92 passed, 0 failed` (was 60/12) |
| 12 | 2,6 | `luau-lsp analyze ... src` + `lune run tests/run` + `rojo build`; old `BurgerJointStep` removed (`grep` → none) | PASS | `lsp exit=0` · `TOTAL: 134 passed, 0 failed` · `Built project to DayOfGlory-test.rbxl` |
| 13 | 5 | Studio (edit-mode preview via command bar): screenshot Burger Joint roof | PASS | marble stand + red rim, umbrella, ROOFTOP FOOD sign, giant burger beside it, stair landing + lamp + roof-wall gap visible |
| 14 | 1,2,5 | Studio 2-client run, server log `grep "\[Food\]"` | PASS | `Bot 6 grabbed RED's sushi!` · `Bot 2 grabbed BLUE's burger!` · `Bot 5 grabbed RED's sushi!` · `Bot 1 grabbed BLUE's sushi!` (sushi/burger = rooftop items: bots climbed Sushi Bar, Arcade and the 16-step Sunny Apts stairs) |
| 15 | 5 | same run: `grep -c FLog::CreatorError` server + 2 clients | PASS | `0` / `0` / `0` |
| 16 | 5 | same run: HUD | PASS | `RED 2/10  BLUE 1/10` at 8:01; feed line small (`Bot 1 scored for Red! (2/10)`); `+1 NICE DELIVERY!` banner ~half previous size |
| 17 | 5 | same run: screenshot inside Pizza Palace | FAIL | white counter/floor tiles/Cook outfit still blown out; `SWITCH CHARACTER HERE` billboard overlaps the banner → all map PointLights ×0.45 brightness ×0.8 range; switch sign 220×40 → 130×22, text `SWITCH CHARACTER` |
| 18 | 5 | after fix: `luau-lsp` + `lune run tests/run` + arena check + build | PASS | `lsp exit=0` · `TOTAL: 134 passed, 0 failed` · `ARENA CHECK: 92 passed, 0 failed` |

## Double-check

## Open items
