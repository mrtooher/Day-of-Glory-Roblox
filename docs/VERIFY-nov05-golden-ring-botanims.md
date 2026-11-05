# Verification record

**Task:** "ok let's make those changes, and three minutes in is fine. the slowdown in the water seemed fine when I played it, not too slow, but noticeable. I think it's fine" — build (1) the Golden Burger: once a match a golden food item on the bridge worth 2 of the 7 points, (2) the swim-ring pickup: grab an orange ring in the lagoon for 8 s with no water slow, (3) fix bots' legs not moving.
**Date:** 2026-11-05
**Run by:** claude-opus-5-5 (frontier tier) · **Mode:** panel authorized (/fable-mode-pro named earlier in this run)

## Stage map

```
Decision: Golden Burger appears 3:00 into the match → yes (user)
Decision: wading speed stays 70% → yes (user: "not too slow, but noticeable")
Decision: golden burger carrier can be tagged by any enemy anywhere (Config.GoldenBurger.taggableAnywhere) → yes (assumed: under the normal rule a carrier running home is never taggable, so it would be a free 2 points)
Decision: dropped golden burger can be picked up by either team; untouched for 10 s it returns to the bridge → yes (assumed)
Decision: 4 swim rings, mirrored, (±20, ±38) in the lagoon bays, respawn 20 s, Water World only → yes (assumed)
Decision: bots go for the golden burger (closest raider per team); bots ignore swim rings → yes (assumed)
Stage 1: Pure rules + specs: Rules/GoldenBurger, Scoring amount, TagResolution "anywhere", Wading.terrainSlow (swim ring), Rules/BotAnim → red then green
  check: fable-checks code.md → "Red, then green" + "Test suite actually ran"
Stage 2: Server/client wiring: GoldenService (new), MapService.bridgeSpot, MatchService.elapsed/awardPoint(amount), FoodService/TagService/StatusService/BotService hooks, PickupService rings, BotAnimation (new) → type check + build
  check: fable-checks-games → "Roblox: type check" (luau-lsp 1.53.1, 0 errors like main) + "offline map or world checks" (City, Water) + rojo build
Stage 3: Bot legs repro → fix → same probe (fable-checks-games → "Reproduce first"): repro = `[BotAnim] … playing 0 botSpeed 14` from the PR #22 playtest log
Stage 4: Install (live place matches repo), Claude-driven playtest: golden appears/grab/score +2/tag anywhere, swim ring removes slow 8 s, bot tracks playing; publish
  check: fable-checks-games → "Roblox: live place matches repo" + "Playtest script" (Claude-driven rows)
```
(no LANDMINES.md)

## Check log

| # | Stage | Check | Result | Evidence |
|---|-------|-------|--------|----------|
| 0 | 3 | Repro (PR #22 playtest, client command bar): bot Animator playing tracks while the bot moves | FAIL | `[BotAnim] bots 7 model Bot 7 rig R15 animateScript LocalScript animator true playing 0 botSpeed 14.000001907348633 \| me animate LocalScript myTracks 2` |
| 1 | 1 | `lune run tests/run` with GoldenBurger/SwimRing/BotAnim specs registered, before the modules existed | FAIL | stack trace ending `Script '/home/claude/day-of-glory-roblox/tests/run', Line 29` (require of missing module) |
| 2 | 1 | `lune run tests/run` after GoldenBurger, BotAnim, Wading.terrainSlow, Scoring amount, Config | PASS | `Rules/BotAnim.spec 3 passed` · `Rules/GoldenBurger.spec 6 passed` · `Rules/Scoring.spec 6 passed` · `Rules/SwimRing.spec 3 passed` · `TOTAL: 183 passed, 0 failed` |
| 3 | 1 | New TagResolution test "golden burger carrier can be tagged anywhere", before the rule changed | FAIL | `FAIL Rules/TagResolution.spec > golden burger carrier can be tagged anywhere, by any enemy: …:67: expected truthy, got false` |
| 4 | 1 | After `anywhere` in TagResolution (skip territory checks; carrier is the one tagged on mutual contact) | PASS | `TOTAL: 184 passed, 0 failed` |
| 5 | 2 | `luau-lsp analyze` 1.53.1 on `src` after wiring | FAIL | `PickupService.luau(124,18): TypeError: Type 'Actor' … could not be converted into 'Actor' from '@roblox'` · `StatusService.luau(98,59): … 'unknown?' could not be converted into 'number?'` · `GoldenService.luau(52,14): …` (untyped tuple table) |
| 6 | 2 | Fixed (Actor type alias, swimRingUntil helper, typed Bit records, xpcall); re-run | PASS | `lsp exit=0`, 0 lines |
| 7 | 2 | `lune run tests/run`; arena-check City + Water; `rojo build -o /tmp/v3.rbxl` | PASS | `TOTAL: 184 passed, 0 failed` · `ARENA CHECK: 105 passed, 0 failed` · `ARENA CHECK: 124 passed, 0 failed` · `Built project to v3.rbxl` |
| 8 | 4 | Pre-install: live length+hash of the 12 changed scripts vs `origin/main` 08fe318 (= v16); new modules absent | PASS | `[PreInst3] Main 707 1954843072 \| BotService 10367 834734825 \| … \| Wading 2372 1917028232 new=nil/nil/nil/nil` = main |
| 9 | 4 | Installer plugin (16 sources, length+hash guard) triggered via `DOGInstall` | PASS | 16 × `ok`, e.g. `GoldenService ok 7832 960378901 created`, `BotAnimation ok 2944 539538899 created`, `Config ok 10801 1980918762 updated` · `[Inst] done` |
| 10 | 3 | Playtest (claude): same bot probe as row 0, Water match, client command bar | PASS | `[BotAnim2] Bot 1 tracks=8 playing=1 [913376220] speed=14.0` · `Bot 2 tracks=8 playing=1 [913376220] speed=20.0` · standing bots `[507766388] speed=0.0` (idle) — was `playing 0` at speed 14 |
| 11 | 4 | Playtest step (claude): swim ring — first try, pivot onto (−20, 38) | UNVERIFIABLE | `[Ring] Bot 1 took a swim ring at (-20, 38)` 0.2 s before I arrived → `onRing … walk=14.00 until=nil` (ring already respawning); probe timing, not a bug |
| 12 | 4 | Playtest step (claude): swim ring — pivot onto an available ring, back into the lagoon, wait past 8 s | PASS | `[Ring] Nuggetdog447 took a swim ring at (20, -38)` · `onRing … wading=true walk=20.00 until=484.3 worn=true` · `lagoon-withRing … wading=true walk=20.00` · `t+8.6 t=484.7 … walk=14.00 worn=false` · screenshot: orange bead ring round the waist, SWIM RING pickup floating nearby |
| 13 | 4 | Playtest step (claude): golden burger appears on the bridge at 3:00 (10:00 match → 7:00 left) | PASS | `[Golden] Appeared at 0, 8.6, 0` · `[Gold] appeared at (0.0,8.6,0.0) clockLeft=420 anchored=true` |
| 14 | 4 | Playtest step (claude): grab it → carrier flags set, normal carry speed | PASS | `[Golden] Nuggetdog447 grabbed the GOLDEN BURGER for Pizza Palace!` · `[Gold] after grab: GoldenCarrier= true Carrying= true walk= 15 goldParentIsMe= true` |
| 15 | 4 | Playtest step (claude): bring it to own dropoff → +2, golden gone | PASS | `[Golden] scored by Nuggetdog447 for Red` · `[Gold] after dropoff: score 3 -> 5 GoldenCarrier= false goldInWorld= false` |
| 16 | 4 | Playtest step (claude): golden carrier tagged on enemy turf / own turf | UNVERIFIABLE | Not hit in this session (I scored 1.8 s after grabbing). Rule covered by row 4 unit test only |
| 17 | 4 | Pre-publish (edit mode, after Stop): live length+hash of all 16 scripts vs repo manifest; repo re-hashed = manifest | PASS | `[PrePub3] Main 725 1874938298 \| BotService 11252 2054984710 \| … \| GoldenBurger 2458 479507642 \| BotAnim 1298 1970273406` = installed; installer plugin not in Plugins folder |
| 18 | 4 | File → Publish | PASS | `Publish succeeded for placeId 110189125329460` · `→ Add publish notes to v17` |

## Self-critique

- Assumed (not asked): golden carrier taggable anywhere (`Config.GoldenBurger.taggableAnywhere`); dropped golden pickable by either team, back to the bridge after 10 s; 4 ring spots, 20 s respawn; bots chase the golden but don't seek rings (they grab rings they walk over).
- HOW TO PLAY card doesn't mention the golden burger or swim rings.
- Golden look (gold foil, sparkles, +2 billboard) not seen in a screenshot — I grabbed it 0.4 s after it appeared.

## Double-check

Cold self-check of the delivery against Jim's ask (golden at 3:00 worth 2; ring 8 s no slow; bot legs; wading unchanged at 70%): rows 10, 12–15, 18 cover each; `Config.Map.water.wading` untouched in the diff. No FAIL.

## Open items

- Tag-anywhere on the golden carrier: unit-tested only (row 16).
- HOW TO PLAY card update.
- Golden visual check in a real match.
