--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuildings = require(script.Parent.MapBuildings)

export type Kitchen = {
	pantry: Vector3,
	dropoff: Vector3,
	spawn: Vector3,
	guard: Vector3,
}

local MapService = {}

local kitchens: { [string]: Kitchen } = {}
local burgerSpawns: { Vector3 } = {}
local arena: Instance

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
	sign.Size = UDim2.fromOffset(220, 40)
	sign.StudsOffset = Vector3.new(0, 9, 0)
	sign.MaxDistance = 80
	sign.Adornee = spawnPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "SWITCH CHARACTER HERE"
	label.Parent = sign
	sign.Parent = disc
end

function MapService.start()
	local existing = Workspace:FindFirstChild("Arena")
	if existing then
		arena = existing
	else
		arena = Instance.new("Folder")
		arena.Name = "Arena"
		MapBuildings.buildArena(arena, Config.Map)
		arena.Parent = Workspace
	end

	for _, t in Config.Teams do
		local pantry = marker(t.id .. "Pantry").Position
		local center = Vector3.new(Config.Map.centerX, pantry.Y, pantry.Z)
		kitchens[t.id] = {
			pantry = pantry,
			dropoff = marker(t.id .. "Dropoff").Position,
			spawn = marker(t.id .. "Spawn").Position,
			guard = pantry:Lerp(center, 0.35),
		}
		buildSwitchZone(t.id, marker(t.id .. "Spawn"))
	end

	local i = 1
	while arena:FindFirstChild("BurgerSpawn" .. i, true) do
		table.insert(burgerSpawns, marker("BurgerSpawn" .. i).Position)
		i += 1
	end
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