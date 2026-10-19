# Tasks for Qwen (paste-ready)

How to use (same workflow as before): paste ONE prompt below into Qwen, then
paste the files it lists (from GitHub, branch `main`). Qwen returns full files.
Send them to Claude to review, fix, test and open the PR. Never merge Qwen
output unreviewed: every past draft needed real fixes.

Each task is small, touches few files, and has a check Claude runs before merge.

---

## Task 1 — Player leaderboard (points + tags)

**Paste these files:** `src/server/Services/MatchService.luau`,
`src/server/Services/TagService.luau`, `src/server/Services/Actors.luau`.

```
You are editing a Roblox game written in Luau (Rojo project, --!strict).
Add a standard Roblox leaderboard (leaderstats) for human players.

Rules:
- On PlayerAdded, create a Folder named "leaderstats" under the Player with two
  IntValues: "Points" and "Tags" (both start at 0).
- When a player scores (MatchService.awardPoint is called with the scoring
  actor), add 1 to that player's Points. Bots have no Player: skip them.
- When a player tags someone (TagService.tag(target, tagger)), add 1 to the
  tagger's Tags if the tagger is a player.
- When a new match starts (MatchService startMatch), reset every player's
  Points and Tags to 0.
- Put the leaderstats code in a NEW file src/server/Services/StatsService.luau
  with functions init(services), start(), addPoint(actor), addTag(actor),
  resetAll(). Call it from MatchService/TagService through the services table
  (services.StatsService). Add "StatsService" to the `order` list in
  src/server/Main.server.luau right after "MatchService".
- Keep --!strict and the existing code style. Do not change any other behaviour.
Return the full content of every file you change or create.
```

**Claude's check:** `luau-lsp analyze` exit 0; `lune run tests/run` 0 failed;
Studio: Tab key shows Points/Tags; scoring adds 1.

---

## Task 2 — "1 minute left" and "10 seconds left" warnings

**Paste:** `src/client/Hud.luau`, `src/shared/Net.luau`.

```
You are editing a Roblox Luau client HUD (--!strict). The match clock is the
replicated attribute "PhaseEndsAt" (server time, seconds) on the
ReplicatedStorage MatchState folder, and "Phase" is "Playing" during a match.
Workspace:GetServerTimeNow() gives the current server time.

Add, inside Hud.start's existing update loop:
- When Phase is "Playing" and the time left first drops to 60 seconds or less,
  flash a centred banner "1 MINUTE LEFT!" for 2 seconds.
- When it first drops to 10 seconds or less, show "10 SECONDS!" for 2 seconds.
- Each warning fires once per match (reset when Phase changes).
- Banner: TextLabel, GothamBlack, white text with black stroke, max size
  420x44 px (UISizeConstraint), centred at 22% from the top, transparent
  background. Don't cover the scoreboard at the top.
Return the full Hud.luau.
```

**Claude's check:** lsp clean; Studio: set `Config.MatchDurationSeconds = 75`
for a test run and see both banners.

---

## Task 3 — End-of-match summary card

**Paste:** `src/client/Hud.luau`, `src/server/Services/MatchService.luau`,
`src/server/Services/Remotes.luau`, `src/shared/Net.luau`.

```
You are editing a Roblox Luau game (--!strict). When a match ends
(MatchService endMatch), the server should send every client a summary:
winner team ("Red"/"Blue"/"Draw"), final scores, and the top scorer's name
(the actor who called awardPoint the most this match; bots count).

- Track per-actor points in MatchService (a table keyed by actor.name, reset in
  startMatch).
- Add a RemoteEvent name "MatchSummary" to Net.luau and add Net.MatchSummary
  to the `for _, name in { Net.RequestPower, ... }` list in Remotes.luau that
  creates the others.
- Fire it with one table: { winner = string, red = number, blue = number,
  mvp = string? }.
- Client (Hud.luau): show a centred card for Config.PostMatchSeconds:
  "RED WINS!" / "BLUE WINS!" / "DRAW!", the score "10 - 7", and
  "MVP: <name>" if present. Card max 360x160 px, rounded corners, dark
  semi-transparent background, team colour title.
Return full files for everything you change.
```

**Claude's check:** lsp clean; tests pass; Studio: let bots finish a short
match and screenshot the card.

---

## Task 4 — Character picker cards (colour + one-line power description)

**Paste:** `src/client/CharacterSelect.luau`, `src/shared/Config.luau`,
`src/shared/Looks.luau`.

```
You are editing a Roblox Luau UI (--!strict). Improve the character picker
buttons in CharacterSelect.luau without changing how picking works
(request:FireServer(c.id), the pending/close logic, Esc/B to close).

- Each button: background tinted with that character's shirt colour from
  Looks.luau (Looks[id].shirt is a hex string like "#3a2a1a"; convert with
  Color3.fromHex and darken so white text stays readable), the character name
  in big text and the power name below (already there).
- Add a one-line description under each, from this table (put it in
  CharacterSelect.luau):
  Kelly "Shout! Knocks enemies back", Sol "Fireball stuns", Vex "Turn
  invisible 5s", Pim "Slow enemies + super jump", Cop "Stun gun bolt",
  Dog "Sprint + sniff out enemies", PizzaMan "Pizza slows", Cook "Grease trap".
- Keep the 4x2 grid and the current panel size.
Return the full CharacterSelect.luau.
```

**Claude's check:** lsp clean; Studio screenshot of the picker.

---

## Not for Qwen (Claude does these)

- Anything in `MapBuildings.luau` (2,500-part generator with an automated
  layout check), `FoodService`, `BotService`, power logic, or the test suite.
- Publishing / settings (Jim does these in Creator Hub).
