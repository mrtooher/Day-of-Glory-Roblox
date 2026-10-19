--!strict
-- All tunable game values live here. Pure data: no Roblox API calls, so it
-- loads in Lune tests and in Studio alike.

local Config = {}

-- Teams ---------------------------------------------------------------------
Config.Teams = {
	{ id = "Red", displayName = "Red Kitchen", color = "Bright red" },
	{ id = "Blue", displayName = "Blue Kitchen", color = "Bright blue" },
}
Config.MinPlayersPerTeam = 4 -- bots fill up to this
Config.MaxPlayersPerTeam = 8
Config.MinHumansToStart = 2

-- Match ---------------------------------------------------------------------
Config.PointsToWin = 10
Config.MatchDurationSeconds = 10 * 60
Config.IntermissionSeconds = 15
Config.PostMatchSeconds = 8

-- Food ----------------------------------------------------------------------
Config.FoodTypes = { "Pizza", "Burger", "Taco", "Sushi" }
Config.PantrySlotsPerType = 1 -- pieces of each food shown in a pantry at once
Config.PantryRestockSeconds = 4
Config.DroppedFoodSeconds = 10
Config.CarrierSpeedMultiplier = 0.75

-- Movement ------------------------------------------------------------------
Config.BaseWalkSpeed = 20 -- 400-stud field: 16 felt like a long walk
Config.BaseJumpPower = 50

-- Tagging -------------------------------------------------------------------
Config.TagRange = 4 -- studs between root parts that counts as a touch
Config.TagImmunitySeconds = 3 -- after respawn

-- Field pickups -------------------------------------------------------------
Config.BurgerBoost = {
	speedMultiplier = 1.6,
	durationSeconds = 3,
	respawnSeconds = 12,
}

-- Characters & powers -------------------------------------------------------
-- Reference values from the Unity game: Yell radius 4.5, cooldowns 5 s,
-- Vanish 3 s, Slow-Mo 3 s, jump x1.7. Treat as starting points.
Config.MaxSameCharacterPerTeam = 2
Config.DefaultCooldownSeconds = 5

Config.Characters = {
	{ id = "Kelly", power = "Yell" },
	{ id = "Sol", power = "Fireball" },
	{ id = "Vex", power = "Vanish" },
	{ id = "Pim", power = "SlowMo" },
	{ id = "Cop", power = "Whistle" },
	{ id = "Dog", power = "Sniff" },
	{ id = "PizzaMan", power = "PizzaToss" },
	{ id = "Cook", power = "GreaseSpill" },
}

Config.Powers = {
	Yell = {
		displayName = "YELL",
		cooldown = 5,
		radius = 12, -- Unity 4.5 was Unity units; 4.5 studs = touching only
		knockback = 85, -- horizontal impulse speed (studs/s)
	},
	Fireball = {
		displayName = "FIREBALL",
		cooldown = 5,
		speed = 75,
		range = 90,
		stunSeconds = 2,
	},
	Vanish = {
		displayName = "VANISH",
		cooldown = 10, -- longer than the vanish so Vex can't stay invisible forever
		durationSeconds = 5,
	},
	SlowMo = {
		displayName = "SLOW-MO",
		cooldown = 5,
		radius = 16,
		durationSeconds = 3,
		speedMultiplier = 0.5,
		passiveJumpMultiplier = 1.7,
	},
	Whistle = {
		displayName = "STUN GUN",
		cooldown = 5,
		speed = 80, -- bolt fired straight ahead; stuns the first enemy it hits
		range = 60,
		freezeSeconds = 2,
	},
	Sniff = {
		displayName = "SNIFF",
		cooldown = 5,
		durationSeconds = 4,
		speedMultiplier = 1.7,
	},
	PizzaToss = {
		displayName = "PIZZA KNIFE",
		cooldown = 5,
		speed = 60,
		range = 70,
		slowSeconds = 2.5,
		speedMultiplier = 0.5,
	},
	GreaseSpill = {
		displayName = "GREASE",
		cooldown = 5,
		lifetimeSeconds = 15,
		radius = 6,
		slowSeconds = 2,
		speedMultiplier = 0.4,
		maxActivePerCook = 2,
	},
}

-- Map (placeholder arena; MapService builds it if Workspace has no "Arena") --
-- Field runs along X. Red owns X < centerX, Blue owns X > centerX.
Config.Map = {
	centerX = 0,
	neutralHalfWidth = 1, -- center strip where nobody can tag
	negativeSideTeam = "Red",
	positiveSideTeam = "Blue",
	fieldLength = 400,
	fieldWidth = 180,
	wallHeight = 20,
	pantryX = 180, -- distance from center line
	dropoffX = 150,
	dropoffZ = 0,
	spawnX = 190,
	spawnZ = 0,
	burgerSpawns = { { x = 0, z = 30 }, { x = 0, z = -30 } },
}

-- Mid-match character switch only within this many studs of your own spawn,
-- and not while carrying food. Between matches you can switch anywhere.
Config.HomeSwitchRadius = 20

Config.FoodPickupRadius = 4 -- studs from a DROPPED food piece to touch it
-- Grabbing from a pantry counter: horizontal distance from your body to a
-- food slot, plus a height window (food sits on a counter top).
Config.FoodGrab = { radius = 6, maxHeight = 6 }

-- Map pads (parts named DashPad1.. / JumpPad1.. in the Arena).
Config.Pads = {
	radius = 4, -- horizontal studs from the pad centre
	dashMultiplier = 1.6,
	dashSeconds = 2,
	jumpVelocity = 95, -- studs/s straight up (players only)
	cooldownSeconds = 1.5, -- per actor per pad
}
Config.DropoffRadius = 6
Config.BurgerPickupRadius = 4
Config.ProjectileHitRadius = 3

-- Bots ----------------------------------------------------------------------
Config.Bots = {
	repathSeconds = 0.75,
	defenderShare = 0.25, -- fraction of a team's bots that guard home
	powerUseChance = 0.35, -- per think tick when a target is in range
	debugLogSeconds = 0, -- >0: print "[Bot]" status lines this often (debugging bots in Studio)
}

-- Audio ---------------------------------------------------------------------
-- Roblox asset IDs (numbers). 0 = no sound yet: that sound is skipped.
-- Music plays in the listed phases; it keeps playing (no restart) when the
-- phase moves from Intermission to Playing.
Config.Audio = {
	musicVolume = 0.5,
	sfxVolume = 0.8,
	fadeSeconds = 1,
	musicPhases = { "Intermission", "Playing" },
	-- Playlist plays in musicPhases, shuffled, next song when one ends.
	-- Names from the Roblox asset details (creator Nuggetdog447).
	playlist = {
		{ id = 140350912499061, name = "Feast for your life" },
		-- 107858682693210 "Kishi In My Kuna" removed: taken down by Roblox moderation 2026-10-19
		{ id = 89048811438062, name = "Neon Horizon" },
	},
	loadTimeoutSeconds = 10, -- skip a song that hasn't loaded by then
	winMusic = 0, -- PostMatch; 0 = silence after the match
	sfx = {
		score = 0,
		countdownBeep = 0, -- last seconds of the pre-match countdown
		countdownGo = 0, -- match start
		-- one per power, played when that power is used (keys = Config.Powers ids)
		Yell = 0,
		Fireball = 0,
		Vanish = 0,
		SlowMo = 0,
		Whistle = 0,
		Sniff = 0,
		PizzaToss = 0,
		GreaseSpill = 0,
	},
	countdownBeepSeconds = 3,
}

-- Input ---------------------------------------------------------------------
Config.PowerKeys = { "Q", "ButtonX" } -- Enum.KeyCode names

return Config
