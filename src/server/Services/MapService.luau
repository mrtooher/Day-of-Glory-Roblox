--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuildings = require(script.Parent.MapBuildings)
local MapWater = require(script.Parent.MapWater)
local Remotes = require(script.Parent.Remotes)

export type Kitchen = {
	pantry: Vector3,
	dropoff: Vector3,
	spawn: Vector3,
	guard: Vector3,
	roofFood: { [number]: Vector3 }, -- top centre of <Team>RoofFood<k> pedestals
}

local MapService = {}

local kitchens: { [string]: Kitchen } = {}
local burgerSpawns: { Vector3 } = {}
local arena: Instance

-- Arena themes (Jim 2026-11-04). The Core layer (kitchens, rooftop food,
-- pads) stays put; only Arena.Theme is swapped, so every cached marker part
-- keeps working. Built themes wait in ServerStorage when not in use.
type Theme = { build: (Instance, { [string]: any }) -> (), lighting: () -> () }
local THEMES: { [string]: Theme } = {
	City = { build = MapBuildings.buildCityTheme, lighting = MapBuildings.cityLighting },
	Water = { build = MapWater.buildTheme, lighting = MapWater.lighting },
}
local themesEnabled = false -- false when the place ships its own Workspace.Arena
local currentArena: string = Config.DefaultArena
local themeFolders: { [string]: Folder } = {}
local themeStore: Folder

local function themeFolder(id: string): Folder
	local cached = themeFolders[id]
	if cached then
		return cached
	end
	local f = Instance.new("Folder")
	f.Name = "Theme"
	f:SetAttribute("ArenaId", id)
	THEMES[id].build(f, Config.Map)
	themeFolders[id] = f
	return f
end

local function teamColor(teamId: string): BrickColor
	for _, t in Config.Teams do
		if t.id == teamId then
			return BrickColor.new(t.color :: any)
		end
	end
	error("unknown team " .. teamId)
end

local function marker(name: string): BasePart
	local p = arena:FindFirstChild(name, true)
	assert(p and p:IsA("BasePart"), "Arena is missing part " .. name)
	return p
end

function MapService.init(_services: any) end

-- Glowing circle at each spawn: the area where you can switch character
-- mid-match (Config.HomeSwitchRadius).
local function buildSwitchZone(teamId: string, spawnPart: BasePart)
	local radius = Config.HomeSwitchRadius
	local floorY = spawnPart.Position.Y - spawnPart.Size.Y / 2
	local disc = Instance.new("Part")
	disc.Name = teamId .. "SwitchZone"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.2, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(spawnPart.Position.X, floorY + 0.12, spawnPart.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = teamColor(teamId).Color
	disc.Transparency = 0.75
	disc.Parent = arena

	local sign = Instance.new("BillboardGui")
	sign.Name = "SwitchSign"
	sign.Size = UDim2.fromOffset(130, 22)
	sign.StudsOffset = Vector3.new(0, 11, 0)
	sign.MaxDistance = 45
	sign.Adornee = spawnPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "SWITCH CHARACTER"
	label.Parent = sign
	sign.Parent = disc
end

function MapService.start()
	local existing = Workspace:FindFirstChild("Arena")
	if existing then
		arena = existing -- custom map: one arena, no vote
	else
		arena = Instance.new("Folder")
		arena.Name = "Arena"
		local core = Instance.new("Folder")
		core.Name = "Core"
		MapBuildings.buildCore(core, Config.Map)
		core.Parent = arena
		themeStore = Instance.new("Folder")
		themeStore.Name = "ArenaThemes"
		themeStore.Parent = ServerStorage
		themeFolder(currentArena).Parent = arena
		THEMES[currentArena].lighting()
		arena.Parent = Workspace
		themesEnabled = true
	end
	Remotes.setState("Arena", currentArena)
	Remotes.setState("ArenaVoting", themesEnabled)

	for _, t in Config.Teams do
		local pantry = marker(t.id .. "Pantry").Position
		local center = Vector3.new(Config.Map.centerX, pantry.Y, pantry.Z)
		local roofFood: { [number]: Vector3 } = {}
		for k = 1, #Config.FoodLayout.roof do
			local p = arena:FindFirstChild(t.id .. "RoofFood" .. k, true)
			if p and p:IsA("BasePart") then
				roofFood[k] = p.Position + Vector3.new(0, p.Size.Y / 2, 0)
			else
				warn("MapService: missing " .. t.id .. "RoofFood" .. k .. " - that food goes on the counter")
			end
		end
		kitchens[t.id] = {
			pantry = pantry,
			dropoff = marker(t.id .. "Dropoff").Position,
			spawn = marker(t.id .. "Spawn").Position,
			guard = pantry:Lerp(center, 0.35),
			roofFood = roofFood,
		}
		buildSwitchZone(t.id, marker(t.id .. "Spawn"))
	end

	local i = 1
	while arena:FindFirstChild("BurgerSpawn" .. i, true) do
		table.insert(burgerSpawns, marker("BurgerSpawn" .. i).Position)
		i += 1
	end

	-- Build the other themes now (off-screen, in ServerStorage) so a vote
	-- doesn't stall the match start.
	if themesEnabled then
		task.defer(function()
			for _, a in Config.Arenas do
				if THEMES[a.id] and not themeFolders[a.id] then
					local f = themeFolder(a.id)
					if f.Parent == nil then
						f.Parent = themeStore
					end
				end
			end
		end)
	end
end

-- Where the golden burger appears: on top of the current arena's BridgeDeck
-- (both themes have one), or mid-field if a custom map has no bridge.
function MapService.bridgeSpot(): Vector3
	local deck = arena and arena:FindFirstChild("BridgeDeck", true)
	if deck and deck:IsA("BasePart") then
		return deck.Position + Vector3.new(0, deck.Size.Y / 2 + 1.6, 0)
	end
	return Vector3.new(Config.Map.centerX, 3, 0)
end

-- True when players can vote for the arena (generated arena, not a custom map).
function MapService.arenaVoting(): boolean
	return themesEnabled
end

function MapService.currentArena(): string
	return currentArena
end

-- Swap the theme around the Core. Returns true if the arena changed.
function MapService.setArena(id: string): boolean
	if not themesEnabled or id == currentArena or THEMES[id] == nil then
		return false
	end
	local old = themeFolders[currentArena]
	local new = themeFolder(id)
	new.Parent = arena -- new ground in before the old one goes
	if old then
		old.Parent = themeStore
	end
	THEMES[id].lighting()
	currentArena = id
	Remotes.setState("Arena", id)
	print("[Arena] now " .. id)
	return true
end

function MapService.kitchen(teamId: string): Kitchen
	local k = kitchens[teamId]
	assert(k, "no kitchen for " .. teamId)
	return k
end

function MapService.enemyOf(teamId: string): string
	for _, t in Config.Teams do
		if t.id ~= teamId then
			return t.id
		end
	end
	error("no enemy team for " .. teamId)
end

function MapService.burgerSpawns(): { Vector3 }
	return burgerSpawns
end

function MapService.teamColor(teamId: string): BrickColor
	return teamColor(teamId)
end

function MapService.spawnCFrame(teamId: string): CFrame
	local s = MapService.kitchen(teamId).spawn
	return CFrame.new(s + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3)))
end

return MapService