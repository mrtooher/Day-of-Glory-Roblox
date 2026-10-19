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
Config.BaseWalkSpeed = 16
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
		radius = 4.5,
		knockback = 60, -- horizontal impulse speed (studs/s)
	},
	Fireball = {
		displayName = "FIREBALL",
		cooldown = 5,
		speed = 60,
		range = 80,
		stunSeconds = 1.5,
	},
	Vanish = {
		displayName = "VANISH",
		cooldown = 5,
		durationSeconds = 3,
	},
	SlowMo = {
		displayName = "SLOW-MO",
		cooldown = 5,
		radius = 12,
		durationSeconds = 3,
		speedMultiplier = 0.5,
		passiveJumpMultiplier = 1.7,
	},
	Whistle = {
		displayName = "WHISTLE",
		cooldown = 5,
		range = 30,
		freezeSeconds = 2,
	},
	Sniff = {
		displayName = "SNIFF",
		cooldown = 5,
		durationSeconds = 3,
		speedMultiplier = 1.5,
	},
	PizzaToss = {
		displayName = "PIZZA TOSS",
		cooldown = 5,
		speed = 45,
		range = 60,
		slowSeconds = 2.5,
		speedMultiplier = 0.5,
	},
	GreaseSpill = {
		displayName = "GREASE",
		cooldown = 5,
		lifetimeSeconds = 12,
		radius = 4,
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

Config.FoodPickupRadius = 4 -- studs from a food piece to grab/touch it
Config.DropoffRadius = 6
Config.BurgerPickupRadius = 4
Config.ProjectileHitRadius = 3

-- Bots ----------------------------------------------------------------------
Config.Bots = {
	repathSeconds = 0.75,
	defenderShare = 0.25, -- fraction of a team's bots that guard home
	powerUseChance = 0.35, -- per think tick when a target is in range
}

-- Input ---------------------------------------------------------------------
Config.PowerKeys = { "Q", "ButtonX" } -- Enum.KeyCode names

return Config
