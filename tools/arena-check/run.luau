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
-- Bot lanes (BotService LANES z = ±70): alleys open end to end.
-- (from y 0.8: a low step like a 0.6 door step is walkable)
expectClear("north alley lane", { -135, 135, 0.8, 6.5, 66, 74 }, { "DashPad", "JumpPad" })
expectClear("south alley lane", { -135, 135, 0.8, 6.5, -74, -66 }, { "DashPad", "JumpPad" })
-- Burger pickups reachable.
for i, b in m.burgerSpawns do
	expectClear("burger spawn " .. i, { b.x - 4, b.x + 4, 0.6, 8, b.z - 4, b.z + 4 }, { "BurgerSpawn" })
end

-- 3b. Rooftop food (Config.FoodLayout.roof): <Team>RoofFood1/2 pedestals on
-- the roofs of the two buildings nearest each base, each reachable by stairs
-- <Team>RoofStair<k>Step<n> (bots can't use jump pads).
local roofSpots = {
	-- [team] = { { name, x1, x2, z1, z2, roofTop } } (building footprint, roof height)
	Red = {
		{ "RedRoofFood1", -135, -105, 35, 65, 13 }, -- Sushi Bar
		{ "RedRoofFood2", -135, -105, -65, -35, 10 }, -- Burger Joint
	},
	Blue = {
		{ "BlueRoofFood1", 105, 135, 35, 65, 24 }, -- Sunny Apts
		{ "BlueRoofFood2", 105, 135, -65, -35, 16 }, -- Arcade
	},
}
local MAX_RISE = 1.6
for team, spots in roofSpots do
	for k, spot in spots do
		local name, x1, x2, z1, z2, roofTop = spot[1], spot[2], spot[3], spot[4], spot[5], spot[6]
		local marker = find(name)
		check(marker ~= nil and marker:IsA("BasePart") and marker.CanCollide, name .. " exists and is collidable")
		if marker then
			local mp = position(marker)
			check(mp.X > x1 and mp.X < x2 and mp.Z > z1 and mp.Z < z2, name .. " inside its building footprint, got " .. tostring(mp))
			local bottom = mp.Y - marker.Size.Y / 2
			check(math.abs(bottom - roofTop) < 0.6, name .. " sits on the roof (bottom ≈ " .. roofTop .. "), got bottom " .. bottom)
			check(marker.Size.Y <= 2.5, name .. " low enough to grab from the roof (height <= 2.5)")
			-- Headroom: food rests on top; a player stands next to it.
			local top = mp.Y + marker.Size.Y / 2
			expectClear(name .. " headroom", { mp.X - 4, mp.X + 4, top + 0.05, top + 7, mp.Z - 4, mp.Z + 4 })
			-- Standing room on the roof around the pedestal (one side at least).
			local sides = 0
			for _, d in { { 5, 0 }, { -5, 0 }, { 0, 5 }, { 0, -5 } } do
				local bx, bz = mp.X + d[1], mp.Z + d[2]
				if #blockers({ bx - 1.5, bx + 1.5, roofTop + 0.3, roofTop + 6, bz - 1.5, bz + 1.5 }) == 0 then
					sides += 1
				end
			end
			check(sides >= 1, name .. " has standing room beside it on the roof")
		end

		-- Stairs: steps 1..N, each rise <= MAX_RISE, first from the ground, last
		-- reaching the roof, headroom above every step.
		local steps = {}
		local n = 1
		while true do
			local st = find(team .. "RoofStair" .. k .. "Step" .. n)
			if not st then
				break
			end
			table.insert(steps, st)
			n += 1
		end
		check(#steps >= 2, team .. "RoofStair" .. k .. " has steps (got " .. #steps .. ")")
		local prevTop = 0
		local riseOk, headOk = true, true
		for i, st in steps do
			local sp = position(st)
			local top = sp.Y + st.Size.Y / 2
			if top - prevTop > MAX_RISE + 0.01 then
				riseOk = false
				print(string.format("  %sRoofStair%dStep%d rise %.2f", team, k, i, top - prevTop))
			end
			prevTop = top
			local a1, b1 = aabb(st)
			local above = blockers({ a1.X, b1.X, top + 0.05, top + 5.5, a1.Z, b1.Z }, { team .. "RoofStair" .. k })
			if #above > 0 then
				headOk = false
				print(string.format("  %sRoofStair%dStep%d blocked above by: %s", team, k, i, table.concat(above, ", ")))
			end
		end
		check(riseOk, team .. "RoofStair" .. k .. " every rise <= " .. MAX_RISE)
		check(headOk, team .. "RoofStair" .. k .. " headroom above every step")
		check(#steps > 0 and math.abs(prevTop - roofTop) <= MAX_RISE, team .. "RoofStair" .. k .. " reaches the roof (last top " .. prevTop .. ", roof " .. roofTop .. ")")
		-- Roof entry: stepping off the top step toward the pedestal must not be
		-- walled off (parapet gap lines up with the landing).
		if #steps > 0 and marker then
			local last = steps[#steps]
			local a1, b1 = aabb(last)
			local mp = position(marker)
			local cx, cz = (a1.X + b1.X) / 2, (a1.Z + b1.Z) / 2
			local dx, dz = mp.X - cx, mp.Z - cz
			local sx, sz = 0, 0
			if math.abs(dx) >= math.abs(dz) then
				sx = if dx > 0 then 3 else -3
			else
				sz = if dz > 0 then 3 else -3
			end
			local entry = blockers({ a1.X + sx, b1.X + sx, prevTop + 0.3, prevTop + 5.5, a1.Z + sz, b1.Z + sz }, { team .. "RoofStair" .. k })
			check(#entry == 0, team .. "RoofStair" .. k .. " opens onto the roof, blocked by: " .. table.concat(entry, ", "))
		end
	end
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
