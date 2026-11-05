# Verification record

**Task:** "yes install and check please" — install PR #22 (knee-deep wading in Water World; POWER button above the touch jump button) in Studio, playtest it, publish if it passes. Follows the PR #22 review (same session).
**Date:** 2026-11-04
**Run by:** claude-opus-5-5 (frontier tier) · **Mode:** panel authorized (/fable-mode-pro by name, earlier message; same run)

## Stage map

```
Decision: publish if the playtest passes → yes (user: "yes" to "install … playtest … then publish if it passes")
Decision: merge PR #22 after publishing → yes (assumed: keeps main = live place)
Stage 1: Pre-install check + install the 9 changed scripts (one-shot plugin) → live = PR head 2e73c30
  check: fable-checks-games → "Roblox: live place matches repo" (before, after)
Stage 2: Playtest, PR's script steps 1–8 → one row per step
  check: fable-checks-games → "Playtest script" (Claude-driven steps; feel steps user-run)
Stage 3: Publish + merge + handoff → publish line, merge sha
  check: fable-checks-games → "Roblox: live place matches repo" (publish); gh api merge response
```
(no LANDMINES.md)

## Check log

| # | Stage | Check | Result | Evidence |
|---|-------|-------|--------|----------|
| 1 | 1 | Command bar pre-install: length + hash of live Main, PowerButtons, MapWater, StatusService, Config, Movement vs `origin/main` b40e866; new modules absent | PASS | `[PreInst] Main 387 1152258545 \| PowerButtons 3896 2883908 \| MapWater 70894 209830558 \| StatusService 3034 2120423900 \| Config 8286 1126136943 \| Movement 1583 1526621846 new=nil/nil/nil` = main's values |
| 2 | 1 | Installer plugin (9 sources embedded with length+hash from the PR head), triggered by `workspace:SetAttribute("DOGInstall", true)`; plugin re-reads each Source | PASS | 9 × `ok`, e.g. `MapWater ok 73064 974241883 updated`, `Wading ok 2372 1917028232 created`, `Main ok 397 1153090235 updated` · `[Inst] done` (= PR head values) |
| 3 | 2 | Playtest step 3 (claude): desktop client, Water match (vote fired from client command bar `RequestArenaVote:FireServer("Water")`) | PASS | screenshot: `SLOW-MO` button bottom-right, HUD `9:38`; log `[Wade] arena Water team Red phase Playing` |
| 4 | 2 | Playtest step 4 (claude): teleport into lagoon / canal, read server-set `Wading` + WalkSpeed; walk through water with `Humanoid:MoveTo` | PASS | `[Wade] lagoon (-25,3.0,35) wading=true walk=14.00` · `canal (-90,3.0,40) wading=true walk=14.00` · `[Splash] emitter true wading true walk 14` · screenshot: legs under water to the knees |
| 5 | 2 | Playtest step 5 (claude): dry street | PASS | `[Wade] dryStreet (-120,3.1,0) wading=false walk=20.00 floor=WoodPlanks` |
| 6 | 2 | Playtest step 6 (claude): first attempt `hum.Jump = true` in water | UNVERIFIABLE | no jump happened (`y=3.0` throughout); character drifted onto planks → probe error, not a game result |
| 7 | 2 | Playtest step 6 (claude) retry: `ChangeState(Jumping)` + upward velocity ×3 in lagoon | PASS | 36 airborne samples all `state=Freefall wading=true walk=14.00 floor=Air` |
| 8 | 2 | Playtest step 7 (claude): islands, dock, bridge deck | PASS | `northIsland (0,4.3,50) wading=false walk=20.00` · `southIsland (-0,4.3,-50) wading=false` · `dock (-44,4.3,45) wading=false` · bridge `(0,10.0,0) wading=false walk=20.00 floor=WoodPlanks` (first try at y 4 landed under the deck: `wading=true`, correct for under-bridge water) |
| 9 | 2 | Playtest step 8 (claude): Pizza Toss while wading | UNVERIFIABLE | no way to force a bot's hit from the client command bar; rule covered offline: `Wading.spec` "wading slows like any slow: strongest slow wins" (in `TOTAL: 170 passed`) |
| 10 | 2 | Playtest step 1 (claude): Device Simulator iPhone XR landscape | PASS | screenshot: `VANISH` button centred above the round jump button, small gap, no overlap |
| 11 | 2 | Playtest step 2 (claude): switch to iPhone 17 Pro, then rotate to portrait | PASS | screenshots: landscape — `VANISH` above jump; portrait — `VANISH` directly above the jump button at bottom-right |
| 12 | 2 | Studio log CreatorError scan during both playtests | PASS | only `Unable to load plugin icon: rbxasset://…/play.png` (installer toolbar icon); 0 game-script errors |
| 13 | 3 | Edit-mode hash check of the 9 scripts after the playtests, then File → Publish | PASS | `[PrePublish22] 73064 974241883 \| 4248 21151917 \| 9863 1916646718 \| 1688 1786950287 \| 1267 1628032951 \| 2372 1917028232 \| 6606 1345670185 \| 2848 1313970201 \| 397 1153090235 arena=nil attr=nil` (= PR head) · `Place published. Eligible players can now play this place in Roblox.` · `→ Add publish notes to v16` |

## Step 4 — self-critique

- Found while playtesting (pre-existing, not from this PR): bots' legs don't animate. Probe: `[BotAnim] … rig R15 animateScript LocalScript animator true playing 0 botSpeed 14.0` vs the player's `myTracks 2`. The bot models carry Roblox's `Animate` **LocalScript**, which never runs on a server-owned NPC, so nothing plays walk/run. Fix belongs in BotService (server-side animation), separate PR.
- Dock and south-island samples read `walk=32.00` (a speed boost was active); the wading result (`false`) is what step 7 checks.
- Installer plugin and its copy moved to ~/.Trash; Device Simulator turned back off.

## Double-check

```
Double-check: 13 log rows + 3 requirements (install, playtest, publish if it passes).
PASS: 11 rows, R1–R3. FIXED after FAIL: 0 (row 6 probe error re-run as row 7). UNVERIFIABLE: 2 — row 6 (probe), row 9 (Pizza Toss hit can't be forced; offline test covers it).
Checkers: self-check — the evidence lives in the Mac's Studio log, which only this thread's device tools can read; every quoted [Wade]/[Wade2]/[Splash]/[Hop2]/publish line re-grepped from the log and matched (21 [Inst] ok lines across both installs, 36/36 Freefall samples wading=true walk=14.00, v16).
```

## Open items

- Does 70% wading speed (≈ 53% for carriers) feel right? Feel step — Jim's call (user-run).
- Bot leg animation (above) — not fixed here.
- Step 8 (slow + wading don't stack) checked offline only.
- Merge decision was `assumed` (keeps main = live).
