--!strict
-- Placeholder arena built from Parts. If Workspace already has a model/folder
-- named "Arena" (e.g. a map built in Studio), it is used as-is; it only needs
-- these named parts: RedPantry, RedDropoff, RedSpawn, BluePantry, BlueDropoff,
-- BlueSpawn, BurgerSpawn1, BurgerSpawn2 (more BurgerSpawnN are fine).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

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

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function sideOf(teamId: string): number
	return if teamId == Config.Map.negativeSideTeam then -1 else 1
end

local function build(): Folder
	local m = Config.Map
	local folder = Instance.new("Folder")
	folder.Name = "Arena"

	local halfLen, halfWid = m.fieldLength / 2, m.fieldWidth / 2

	for _, t in Config.Teams do
		local side = sideOf(t.id)
		local color = teamColor(t.id)

		part({
			Name = t.id .. "Floor",
			Size = Vector3.new(halfLen, 1, m.fieldWidth),
			Position = Vector3.new(m.centerX + side * halfLen / 2, -0.5, 0),
			Color = color.Color:Lerp(Color3.new(1, 1, 1), 0.7),
			Parent = folder,
		})

		part({
			Name = t.id .. "Pantry",
			Size = Vector3.new(4, 3, 16),
			Position = Vector3.new(m.centerX + side * m.pantryX, 1.5, 0),
			BrickColor = color,
			Material = Enum.Material.WoodPlanks,
			Parent = folder,
		})

		part({
			Name = t.id .. "Dropoff",
			Size = Vector3.new(Config.DropoffRadius * 2, 0.2, Config.DropoffRadius * 2),
			Position = Vector3.new(m.centerX + side * m.dropoffX, 0.1, m.dropoffZ),
			BrickColor = color,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
			Parent = folder,
		})

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = t.id .. "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(m.centerX + side * m.spawnX, 0.5, m.spawnZ)
		spawn.BrickColor = color
		spawn.TeamColor = color
		spawn.Neutral = false
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0
		spawn.Parent = folder
	end

	part({
		Name = "CenterLine",
		Size = Vector3.new(m.neutralHalfWidth * 2, 0.2, m.fieldWidth),
		Position = Vector3.new(m.centerX, 0.1, 0),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = folder,
	})

	local walls = {
		{ Vector3.new(m.fieldLength, m.wallHeight, 1), Vector3.new(m.centerX, m.wallHeight / 2, halfWid) },
		{ Vector3.new(m.fieldLength, m.wallHeight, 1), Vector3.new(m.centerX, m.wallHeight / 2, -halfWid) },
		{ Vector3.new(1, m.wallHeight, m.fieldWidth), Vector3.new(m.centerX + halfLen, m.wallHeight / 2, 0) },
		{ Vector3.new(1, m.wallHeight, m.fieldWidth), Vector3.new(m.centerX - halfLen, m.wallHeight / 2, 0) },
	}
	for i, w in walls do
		part({
			Name = "Wall" .. i,
			Size = w[1],
			Position = w[2],
			Transparency = 0.6,
			Color = Color3.fromRGB(200, 200, 200),
			Parent = folder,
		})
	end

	for i, b in m.burgerSpawns do
		part({
			Name = "BurgerSpawn" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 5, 5),
			CFrame = CFrame.new(m.centerX + b.x, 0.1, b.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 200, 60),
			CanCollide = false,
			Parent = folder,
		})
	end

	folder.Parent = Workspace
	return folder
end

local function marker(name: string): BasePart
	local p = arena:FindFirstChild(name, true)
	assert(p and p:IsA("BasePart"), "Arena is missing part " .. name)
	return p
end

function MapService.init(_services) end

function MapService.start()
	local existing = Workspace:FindFirstChild("Arena")
	arena = existing or build()

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

-- A spot near the team's spawn, a little randomised so respawns don't stack.
function MapService.spawnCFrame(teamId: string): CFrame
	local s = MapService.kitchen(teamId).spawn
	return CFrame.new(s + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3)))
end

return MapService
