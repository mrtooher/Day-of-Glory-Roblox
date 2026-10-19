# The Day of Glory — Roblox

Kelly and friends chase takeout food. Two teams raid each other's kitchens:
grab food from the enemy pantry, carry it to your own drop-off, first team to
**10** wins (backup 10-minute clock: most points wins). Tag, don't kill — no
weapons, no blood.

This repo is a [Rojo](https://rojo.space) project written in Luau.

## Layout

```
default.project.json      Rojo mapping
src/shared/   → ReplicatedStorage.Shared
  Config.luau             every tunable number (teams, scoring, powers, map, bots)
  Net.luau                remote / state names shared by server and client
  Rules/                  pure game rules, no Roblox API calls (unit tested)
    Scoring, MatchEnd, MatchPhase, Territory, TagResolution,
    FoodState, TeamPick, Movement, BotBrain, AudioRules, CharacterSwitch
  Powers/                 PowerBase (shared cooldown class) + one module per power
src/server/   → ServerScriptService.Server
  Main.server.luau        boots the services
  Services/               Remotes, Actors, MapService, StatusService, MatchService,
                          FoodService, PickupService, Effects, PowerService,
                          TagService, CharacterService, BotService
src/client/   → StarterPlayer.StarterPlayerScripts.Client
  Main.client.luau        boots the client modules
  Hud, PowerButtons, CharacterSelect, Visibility, PowerFx, Audio
tests/                    Lune test runner + specs for Rules, Powers and Config
```

The server is authoritative: clients only send "use my power" and "I want
character X". Scoring, tagging, food pickup and cooldowns are decided from
server-side positions.

## Characters

| Character | Power |
|---|---|
| Kelly | YELL — knock back enemies nearby; an enemy carrier drops their food |
| Sol | FIREBALL — projectile; stuns the target briefly |
| Vex | VANISH — invisible + untaggable for 5 s (10 s cooldown); ends when Vex grabs food |
| Pim | SLOW-MO — slows enemies nearby; passive super jump (x1.7) |
| Cop | STUN GUN — fires a bolt straight ahead; freezes the first enemy it hits |
| Dog | SNIFF — sprint, and reveal vanished Vexes and food carriers |
| Pizza Man | PIZZA TOSS — spinning pizza slows whoever it hits |
| Cook | GREASE SPILL — trap that slows enemy raiders who cross it |

Max 2 of the same character per team. A human who picks a character a bot is
using takes it; the bot switches. Characters can be changed anywhere between
matches; during a match only inside your base's glowing circle
(`Config.HomeSwitchRadius`) and not while carrying food. Switching keeps your
current power cooldown.

Controls: power = **Q** (keyboard), **X** (gamepad), or the on-screen button on
phones/tablets. The **CHARACTER** button (bottom-left) opens the picker. The **SOUND** button
next to it mutes / unmutes music and effects.

## Audio

All sound ids live in `Config.Audio` (an id of 0 is skipped). A 3-song playlist
(`Config.Audio.playlist`) plays shuffled through the pre-match countdown and
the match (next song when one ends, never the same song twice in a row), and
fades out when the match ends. Effect
slots (score, countdown beeps, one per power) are wired but empty until ids
are added.

## Tools

Pinned in `rokit.toml`. Install [Rokit](https://github.com/rojo-rbx/rokit), then:

```sh
rokit install
```

## Running the tests

```sh
lune run tests/run
```

Confirmed working in this repo with Lune 0.10.4: `TOTAL: 111 passed, 0 failed`.
The runner exits non-zero on any failure, when no tests ran, or when a
`*.spec.luau` file exists but is not listed in `tests/run.luau`.

Type-checking the Roblox code (optional, catches misspelled or made-up Roblox
APIs), using [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) 1.53.1 and its
matching definitions file (`scripts/globalTypes.d.luau` at tag `1.53.1`):

```sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
```

## Playing it in Roblox Studio (Mac)

1. Install Roblox Studio and the Rojo Studio plugin (`rojo plugin install`, or
   from the Creator Store).
2. In this folder run:
   ```sh
   rojo serve
   ```
3. In Studio open a new Baseplate place, open the **Rojo** plugin, and click
   **Connect** (default `localhost:34872`). The code syncs into the place.
4. Delete the default Baseplate and SpawnLocation (the game builds its own
   placeholder arena), then press **Play**. With one player bots fill both
   teams, but a match needs 2 humans to start: on Studio's **Test** tab, start
   a local server with 2 players.
5. Optional: build your own map. Put a Model/Folder named `Arena` in Workspace
   containing parts named `RedPantry`, `RedDropoff`, `RedSpawn` (a
   SpawnLocation), `BluePantry`, `BlueDropoff`, `BlueSpawn`, `BurgerSpawn1`,
   `BurgerSpawn2`. Territory is split at X = `Config.Map.centerX`: Red owns
   negative X, Blue positive X.
6. Set the place's max players to 16 in its settings (8v8).

To build a place file without Studio: `rojo build -o DayOfGlory.rbxl`.

## Not testable without Studio

These were written against the Roblox API (checked with the type-checker
above and the Roblox API dump) but have **not been run in Roblox**:

- All of `src/server` and `src/client`: match flow, Teams, spawns, food
  parts and welding, tagging contact, power effects, projectiles, traps.
- Bot spawning (`Players:CreateHumanoidModelFromDescriptionAsync`), the
  block-rig fallback, and pathfinding movement.
- Knockback strength (`BasePart:ApplyImpulse` on player characters), which
  needs tuning in play.
- Touch button placement and size on real phones (`ContextActionService`).
- Client visuals: hiding vanished Vex, carrier markers, SNIFF highlights.
- Distances in `Config` (pickup radius, tag range, map size) and the feel of
  speeds and cooldowns.
- Content maturity: the game is designed for Minimal/Mild (no weapons, no
  blood), but the questionnaire is filled in on the Creator Dashboard.
