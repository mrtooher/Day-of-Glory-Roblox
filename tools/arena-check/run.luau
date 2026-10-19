--!nocheck
-- Offline arena check: `lune run tools/arena-check/run`
-- Runs MapBuildings.buildArena in Lune's Roblox DOM (no Studio) and checks
-- the gameplay contract: markers exist, kitchens are reachable, spawn /
-- doorways / drop-offs / main street are not blocked, and the part budget.
-- Exits non-zero on any failure.

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local game = roblox.Instance.new("DataModel")
local env = setmetatable({
	game = game,
	workspace = game:GetService("Workspace"),
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	BrickColor = roblox.BrickColor,
	Enum = roblox.Enum,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	Font = roblox.Font,
	PhysicalProperties = roblox.PhysicalProperties,
	Rect = roblox.Rect,
}, { __index = _G })

local src = fs.readFile("src/server/Services/MapBuildings.luau")
local MapBuildings = luau.load(src, { debugName = "MapBuildings", environment = env })()
local Config = require("../../src/shared/Config")
local m = Config.Map

local folder = roblox.Instance.new("Folder")
folder.Name = "Arena"
MapBuildings.buildArena(folder, m)

local failures = 0
local passes = 0
local function check(ok: boolean, label: string)
	if ok then
		passes += 1
	else
		failures += 1
		print("FAIL " .. label)
	end
end

local parts = {}
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end

-- Lune keeps Position and CFrame as separate raw properties: a part placed
-- with only Position reports an identity CFrame. Real Roblox keeps them in sync.
local function worldCFrame(p)
	local okC, cf = pcall(function()
		return p.CFrame
	end)
	local okP, pos = pcall(function()
		return p.Position
	end)
	if okC and cf and cf.Position.Magnitude > 1e-6 then
		return cf
	elseif okP and pos then
		return if okC and cf then roblox.CFrame.new(pos) * (cf - cf.Position) else roblox.CFrame.new(pos)
	end
	return if okC and cf then cf else roblox.CFrame.new()
end

local function position(p)
	return worldCFrame(p).Position
end

-- World-space AABB of a part (box approximation for every shape).
local function aabb(p)
	local cf, s = worldCFrame(p), p.Size / 2
	local minV = roblox.Vector3.new(math.huge, math.huge, math.huge)
	local maxV = roblox.Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = cf * roblox.Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
				minV = roblox.Vector3.new(math.min(minV.X, w.X), math.min(minV.Y, w.Y), math.min(minV.Z, w.Z))
				maxV = roblox.Vector3.new(math.max(maxV.X, w.X), math.max(maxV.Y, w.Y), math.max(maxV.Z, w.Z))
			end
		end
	end
	return minV, maxV
end

local EPS = 0.05
-- Collidable parts overlapping the box (minX,maxX, minY,maxY, minZ,maxZ).
local function blockers(box, allowPrefixes)
	local list = {}
	for _, p in parts do
		if p.CanCollide then
			local skip = false
			for _, prefix in allowPrefixes or {} do
				if string.sub(p.Name, 1, #prefix) == prefix then
					skip = true
				end
			end
			if not skip then
				local a, b = aabb(p)
				if a.X < box[2] - EPS and b.X > box[1] + EPS
					and a.Y < box[4] - EPS and b.Y > box[3] + EPS
					and a.Z < box[6] - EPS and b.Z > box[5] + EPS then
					table.insert(list, p.Name)
				end
			end
		end
	end
	return list
end

local function expectClear(label, box, allow)
	local b = blockers(box, allow)
	check(#b == 0, label .. " blocked by: " .. table.concat(b, ", "))
end

-- 1. Markers --------------------------------------------------------------
local function find(name)
	return folder:FindFirstChild(name, true)
end
for _, t in { "Red", "Blue" } do
	for _, k in { "Pantry", "Dropoff", "Spawn" } do
		local p = find(t .. k)
		check(p ~= nil and p:IsA("BasePart"), "marker " .. t .. k .. " exists")
	end
	local sp = find(t .. "Spawn")
	check(sp ~= nil and sp.ClassName == "SpawnLocation", t .. "Spawn is a SpawnLocation")
end
check(find("BurgerSpawn1") ~= nil and find("BurgerSpawn2") ~= nil, "BurgerSpawn1/2 exist")

-- 2. Pantry counter contract: Size (4,3,14) centred (±pantryX, 1.5, 0) ------
for sign, t in { [-1] = "Red", [1] = "Blue" } do
	local p = find(t .. "Pantry")
	if p then
		local pos, size = position(p), p.Size
		check(math.abs(pos.X - sign * m.pantryX) < 0.01 and math.abs(pos.Y - 1.5) < 0.01 and math.abs(pos.Z) < 0.01,
			t .. "Pantry centred at (" .. sign * m.pantryX .. ", 1.5, 0), got " .. tostring(pos))
		check(math.abs(size.X - 4) < 0.01 and math.abs(size.Y - 3) < 0.01 and math.abs(size.Z - 14) < 0.01,
			t .. "Pantry size (4,3,14), got " .. tostring(size))
	end
end

-- 3. Keep-clear zones: y 0.5..6.5 (a character is ~5.5 tall; a ceiling above
-- that is fine) ------------------------------------------------------------
for sign, t in { [-1] = "Red", [1] = "Blue" } do
	local function xr(a, b) -- x range on this team's side, given as distances from centre
		local x1, x2 = sign * a, sign * b
		return math.min(x1, x2), math.max(x1, x2)
	end
	-- Grab zone: in front of the counter (field side), where raiders stand.
	local gx1, gx2 = xr(m.pantryX - 2, m.pantryX - 16)
	expectClear(t .. " grab zone", { gx1, gx2, 0.5, 6.5, -9, 9 })
	-- Walk lanes from spawn (behind the counter) around both ends of it.
	local lx1, lx2 = xr(m.spawnX + 6, m.pantryX - 14)
	expectClear(t .. " north lane", { lx1, lx2, 0.5, 6.5, 8.5, 13 })
	expectClear(t .. " south lane", { lx1, lx2, 0.5, 6.5, -13, -8.5 })
	-- Spawn pad area.
	local sx1, sx2 = xr(m.spawnX - 5, m.spawnX + 5)
	expectClear(t .. " spawn area", { sx1, sx2, 1.1, 6.5, m.spawnZ - 5, m.spawnZ + 5 })
	-- Shop doorway / front opening onto the field.
	local fx1, fx2 = xr(m.pantryX - 8, m.pantryX - 20)
	expectClear(t .. " shop front opening", { fx1, fx2, 0.5, 6.5, -16, 16 })
	-- Drop-off pad.
	local dx1, dx2 = xr(m.dropoffX - 8, m.dropoffX + 8)
	expectClear(t .. " drop-off", { dx1, dx2, 0.5, 6.5, m.dropoffZ - 8, m.dropoffZ + 8 })
end

-- Main street corridor between the bases (ramps/bridge/pads are walkable).
expectClear("main street corridor", { -140, 140, 0.5, 9, -12, 12 }, { "Ramp", "Bridge", "DashPad", "JumpPad" })
-- Burger pickups reachable.
for i, b in m.burgerSpawns do
	expectClear("burger spawn " .. i, { b.x - 4, b.x + 4, 0.6, 8, b.z - 4, b.z + 4 }, { "BurgerSpawn" })
end

-- 4. Pads -------------------------------------------------------------------
local dash, jump = 0, 0
for _, p in parts do
	if string.match(p.Name, "^DashPad%d+$") then
		dash += 1
		check(position(p).Y < 1.2 and not p.CanCollide, p.Name .. " flat on the ground, non-colliding")
	elseif string.match(p.Name, "^JumpPad%d+$") then
		jump += 1
		check(not p.CanCollide, p.Name .. " non-colliding")
		local pp = position(p)
		local px, pz = pp.X, pp.Z
		local above = blockers({ px - 3, px + 3, pp.Y + 1, pp.Y + 40, pz - 3, pz + 3 })
		check(#above == 0, p.Name .. " has open sky above, blocked by: " .. table.concat(above, ", "))
	end
end
check(dash >= 4, "at least 4 DashPads (got " .. dash .. ")")
check(jump >= 2, "at least 2 JumpPads (got " .. jump .. ")")

-- 5. Budget and sanity --------------------------------------------------------
check(#parts < 4000, "part count < 4000 (got " .. #parts .. ")")
local unanchored = 0
local outside = 0
for _, p in parts do
	if not p.Anchored then
		unanchored += 1
	end
	local pp = position(p)
	if math.abs(pp.X) > m.fieldLength / 2 + 30 or math.abs(pp.Z) > m.fieldWidth / 2 + 30 then
		outside += 1
	end
end
check(unanchored == 0, "all parts anchored (" .. unanchored .. " not)")
check(outside == 0, "no parts far outside the field (" .. outside .. ")")

local signs = 0
for _, d in folder:GetDescendants() do
	if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
		signs += 1
	end
end
check(signs >= 10, "at least 10 signs (got " .. signs .. ")")

print(string.format("arena: %d parts, %d dash pads, %d jump pads, %d signs", #parts, dash, jump, signs))
print(string.format("ARENA CHECK: %d passed, %d failed", passes, failures))
if failures > 0 or passes == 0 then
	process.exit(1)
end
