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