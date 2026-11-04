--!strict
-- MapWater: the "Water World" arena theme (Jim 2026-11-04: second arena,
-- players vote). Builds only the Theme layer; the Core (both kitchens,
-- rooftop food stands + stairs, burger spawns, dash/jump pads) comes from
-- MapBuildings.buildCore and is shared with the City theme.
--
-- Same street grid as the City so the gameplay contract (tools/arena-check)
-- holds: boardwalk main street Z -20..20, promenades Z ±(20..35), shop row
-- Z ±(35..65) with the four rooftop-food shops at X ±120 (30x30x13, same
-- parapet gaps as the City) and four more at X ±70, canals in the side
-- streets X ±(85..105), sun decks on the corner plazas, back boardwalk
-- Z ±(65..79) and a beach strip up to the sea wall. A turquoise lagoon fills
-- |X| < 50 with a wooden bridge on the main street; the ocean, piers, boats,
-- islands and a lighthouse lie outside the (invisible) boundary walls.
--
-- Water inside the field is cosmetic: translucent non-colliding planes a few
-- hundredths of a stud above the sand, so the walkable floor stays at y = 0.
-- Everything outside the walls is non-colliding scenery.
local MapBuildings = require(script.Parent.MapBuildings)
local K = MapBuildings.kit

local MapWater = {}

type Spec = { [string]: any }

local V, CF, C, M = K.V, K.CF, K.C, K.M
local ry, UP = K.ry, K.UP
local solid, deco, flat, neon, glass = K.solid, K.deco, K.flat, K.neon, K.glass
local cyl, vcyl, ball, wedge = K.cyl, K.vcyl, K.ball, K.wedge
local light, newFolder, triangle, rope = K.light, K.newFolder, K.triangle, K.rope
local sign, faceCF, awning = K.sign, K.faceCF, K.awning
local WHITE, BLACK, GOLD = K.WHITE, K.BLACK, K.GOLD
-- tools/arena-check loads this module with only `script` and `require`
-- injected, so build code reaches Roblox types through the kit (CF is
-- CFrame.new, M is Enum.Material). The sign font is the one exception: it
-- falls back to the signs' default font when Enum is missing (offline only).
local FONT: Enum.Font? = if Enum then Enum.Font.FredokaOne else nil

-- Rotations about X and Z built from CFrame.new's rotation-matrix form.
local function rx(deg: number): CFrame
	local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
	return CF(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function rz(deg: number): CFrame
	local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
	return CF(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end

-- Palette -------------------------------------------------------------------
local SAND = C(238, 214, 160)
local DRY_SAND = C(246, 228, 182)
local WET_SAND = C(208, 182, 128)
local DECK = C(176, 124, 78)
local DECK_LIGHT = C(204, 156, 104)
local DECK_DARK = C(118, 80, 50)
local DRIFTWOOD = C(170, 150, 125)
local LAGOON = C(70, 210, 225)
local LAGOON_BED = C(120, 222, 205)
local LAGOON_DEEP = C(40, 170, 195)
local OCEAN = C(25, 150, 205)
local CORAL = C(255, 115, 95)
local TURQ = C(0, 195, 190)
local SUNNY = C(255, 210, 50)
local HIBISCUS = C(255, 70, 140)
local LIME = C(140, 215, 60)
local SEA_BLUE = C(35, 120, 215)
local ORANGE = C(255, 140, 40)
local FROND = { C(55, 165, 70), C(80, 190, 65), C(45, 140, 60) }
local TRUNK = { C(150, 112, 72), C(125, 90, 56) }
local ROCK = C(130, 128, 122)
local STRAW = C(214, 178, 108)
local UMBRELLAS = {
	{ CORAL, WHITE }, { TURQ, SUNNY }, { HIBISCUS, WHITE }, { SEA_BLUE, WHITE }, { SUNNY, ORANGE }, { LIME, WHITE },
}
local TOWELS = { { CORAL, WHITE }, { TURQ, WHITE }, { SUNNY, HIBISCUS }, { SEA_BLUE, SUNNY }, { HIBISCUS, LIME } }

-- Deterministic pseudo-random numbers (Park-Miller), so every build matches.
local seed = 20261104
local function rnd(): number
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end
local function rrange(a: number, b: number): number
	return a + (b - a) * rnd()
end

-- Basic water pieces ---------------------------------------------------------

-- Translucent water plane over the box x1..x2, z1..z2 (centre height y).
local function water(parent: Instance, name: string, x1: number, x2: number, z1: number, z2: number, y: number, color: Color3, transp: number, thick: number?): BasePart
	local p = flat(parent, name, V(x2 - x1, thick or 0.04, z2 - z1), CF((x1 + x2) / 2, y, (z1 + z2) / 2), color, M.Glass)
	p.Transparency = transp
	p.Reflectance = 0.12
	return p
end

-- Rectangle of shallow water with a rectangular hole (pieces around it).
local function waterWithHole(parent: Instance, name: string, x1: number, x2: number, z1: number, z2: number, hx1: number, hx2: number, hz1: number, hz2: number, y: number, color: Color3, transp: number)
	hx1, hx2 = math.max(hx1, x1), math.min(hx2, x2)
	hz1, hz2 = math.max(hz1, z1), math.min(hz2, z2)
	local function piece(a1: number, a2: number, b1: number, b2: number)
		if a2 - a1 > 0.05 and b2 - b1 > 0.05 then
			water(parent, name, a1, a2, b1, b2, y, color, transp)
		end
	end
	piece(x1, x2, z1, hz1)
	piece(x1, x2, hz2, z2)
	piece(x1, hx1, hz1, hz2)
	piece(hx2, x2, hz1, hz2)
end

-- Props ---------------------------------------------------------------------

-- Palm tree: curved segmented trunk leaning toward `yawDeg` (0 = +X, 90 = +Z),
-- `bend` studs of sideways curve at the top, drooping two-piece fronds and
-- coconuts. Only the bottom trunk segment collides; `far` = a cheaper,
-- fully non-colliding palm for scenery outside the walls.
local function palm(parent: Instance, base: Vector3, height: number?, yawDeg: number?, bend: number?, far: boolean?)
	local H = height or 14
	local yaw = math.rad(yawDeg or 0)
	local dir = V(math.cos(yaw), 0, math.sin(yaw))
	local b = bend or 3
	local segs = if far then 3 else 4
	local function at(t: number): Vector3
		return base + dir * (b * t * t) + V(0, H * t, 0)
	end
	for i = 1, segs do
		local p0, p1 = at((i - 1) / segs), at(i / segs)
		local axis = p1 - p0
		local mid = (p0 + p1) / 2
		local horiz = math.sqrt(axis.X * axis.X + axis.Z * axis.Z)
		local tilt = math.atan2(horiz, axis.Y)
		local cf = CF(mid) * ry(-math.deg(yaw)) * rz(-math.deg(tilt)) * UP
		local d = 1.5 - (i - 1) * 0.16
		cyl(parent, if i == 1 then "PalmTrunkBase" else "PalmTrunk", V(axis.Magnitude * 1.12, d, d), cf, TRUNK[i % 2 + 1], M.Wood, i == 1 and not far)
	end
	local top = at(1)
	ball(parent, "PalmCrown", 1.6, CF(top), C(110, 120, 50), M.Grass)
	if not far then
		for k = 0, 1 do
			local a = k * math.pi + 0.5
			ball(parent, "Coconut", 0.9, CF(top + V(math.cos(a) * 0.7, -0.7, math.sin(a) * 0.7)), C(110, 75, 40), M.Wood)
		end
	end
	local n = if far then 4 else 5
	for k = 0, n - 1 do
		local a = k / n * 360 + (yawDeg or 0) * 0.5 + 15
		local frame = CF(top) * ry(a)
		local up = if k % 2 == 0 then 22 else 8
		local inner = frame * rx(up)
		deco(parent, "PalmFrond", V(1.7, 0.2, 4.4), inner * CF(0, 0, -2.1), FROND[k % 3 + 1], M.Grass)
		local tip = inner * CF(0, 0, -4.2)
		deco(parent, "PalmFrondTip", V(1.2, 0.18, 4), tip * rx(-50) * CF(0, 0, -1.9), FROND[(k + 1) % 3 + 1], M.Grass)
	end
end

-- Surfboard centred at cf: length along cf's Z (round nose at -Z, square
-- tail), flat in cf's XZ plane.
local function surfboard(parent: Instance, cf: CFrame, len: number, width: number, color: Color3, stripe: Color3)
	deco(parent, "Surfboard", V(width, 0.3, len - width / 2), cf * CF(0, 0, width / 4), color)
	vcyl(parent, "SurfboardNose", 0.3, width, cf * CF(0, 0, -(len - width) / 2), color)
	deco(parent, "SurfboardStripe", V(width * 0.18, 0.34, len - width), cf, stripe)
end

-- Upright surfboard (nose up) standing on the ground at cf, face toward cf's -Z.
local function standingBoard(parent: Instance, cf: CFrame, len: number, color: Color3, stripe: Color3, width: number?)
	surfboard(parent, cf * CF(0, len / 2, 0) * rx(90), len, width or 1.8, color, stripe)
end

-- Rack of upright boards; cf at ground, boards face cf's -Z.
local function surfRack(parent: Instance, cf: CFrame, count: number)
	local span = count * 2.2
	for _, sx in { -1, 1 } do
		solid(parent, "RackPost", V(0.4, 3.4, 0.4), cf * CF(sx * (span / 2 + 0.4), 1.7, 0.5), DECK_DARK, M.Wood)
	end
	deco(parent, "RackBar", V(span + 1.2, 0.3, 0.3), cf * CF(0, 3.2, 0.5), DECK_DARK, M.Wood)
	deco(parent, "RackBar", V(span + 1.2, 0.3, 0.3), cf * CF(0, 0.6, 0.5), DECK_DARK, M.Wood)
	for i = 1, count do
		local col = UMBRELLAS[(i - 1) % #UMBRELLAS + 1]
		standingBoard(parent, cf * CF(-span / 2 + (i - 0.5) * 2.2, 0, 0.2) * rx(-8), 6.5, col[1], col[2])
	end
end

-- Beach umbrella with a towel beside it; cf at ground.
local function beachUmbrella(parent: Instance, cf: CFrame, cols: { Color3 }, towel: { Color3 }?)
	local tiltCF = cf * rz(8)
	solid(parent, "UmbrellaPole", V(0.25, 7.2, 0.25), tiltCF * CF(0, 3.6, 0), WHITE, M.Metal)
	vcyl(parent, "UmbrellaCanopy", 0.3, 8, tiltCF * CF(0, 7, 0), cols[1], M.Fabric)
	vcyl(parent, "UmbrellaCanopyTop", 0.4, 4.4, tiltCF * CF(0, 7.35, 0), cols[2], M.Fabric)
	ball(parent, "UmbrellaFinial", 0.6, tiltCF * CF(0, 7.7, 0), cols[1])
	if towel then
		local t = cf * CF(2.6, 0.04, 0.5) * ry(12)
		flat(parent, "BeachTowel", V(2.4, 0.06, 5), t, towel[1], M.Fabric)
		flat(parent, "TowelStripe", V(2.42, 0.07, 0.9), t, towel[2], M.Fabric)
	end
end

-- Beach lounger; whoever lies on it faces cf's -Z.
local function lounger(parent: Instance, cf: CFrame, color: Color3)
	solid(parent, "LoungerSeat", V(2.2, 0.3, 3.4), cf * CF(0, 0.9, 0.4), color, M.Fabric)
	deco(parent, "LoungerBack", V(2.2, 0.3, 2.4), cf * CF(0, 1.7, 2.7) * rx(-50), color, M.Fabric)
	deco(parent, "LoungerLegs", V(1.6, 0.75, 2.8), cf * CF(0, 0.38, 0.4), WHITE, M.Metal)
end

local function crab(parent: Instance, cf: CFrame)
	local red = C(230, 70, 50)
	deco(parent, "Crab", V(1.6, 0.6, 1.1), cf * CF(0, 0.35, 0), red)
	for _, sx in { -1, 1 } do
		ball(parent, "CrabClaw", 0.65, cf * CF(sx * 1.05, 0.45, -0.75), red)
	end
	deco(parent, "CrabLegs", V(2.5, 0.12, 0.5), cf * CF(0, 0.2, 0.3), red)
	deco(parent, "CrabEyes", V(0.9, 0.25, 0.2), cf * CF(0, 0.75, -0.45), BLACK)
end

local function starfish(parent: Instance, cf: CFrame, color: Color3)
	for k = 0, 4 do
		local a = cf * ry(k * 72)
		flat(parent, "Starfish", V(0.45, 0.14, 1.3), a * CF(0, 0.07, -0.55), color)
	end
end

local function shell(parent: Instance, cf: CFrame, color: Color3)
	ball(parent, "Shell", 0.7, cf * CF(0, 0.15, 0), color)
	wedge(parent, "ShellLip", V(0.6, 0.3, 0.5), cf * CF(0, 0.15, 0.45), color)
end

local function seagull(parent: Instance, cf: CFrame, flying: boolean?)
	local grey = C(150, 155, 165)
	deco(parent, "Gull", V(0.7, 0.6, 1.6), cf * CF(0, 0.6, 0), WHITE)
	ball(parent, "GullHead", 0.62, cf * CF(0, 1.2, -0.85), WHITE)
	deco(parent, "GullBeak", V(0.15, 0.15, 0.5), cf * CF(0, 1.15, -1.3), C(255, 190, 40))
	if flying then
		for _, sx in { -1, 1 } do
			deco(parent, "GullWing", V(2.4, 0.1, 0.8), cf * CF(sx * 1.4, 0.95, 0) * rz(sx * 18), grey)
		end
	else
		for _, sx in { -1, 1 } do
			deco(parent, "GullWing", V(0.12, 0.45, 1.25), cf * CF(sx * 0.4, 0.8, 0.15), grey)
		end
	end
end

-- Tiki torch: bamboo pole (collidable), basket and a glowing flame.
local function tikiTorch(parent: Instance, pos: Vector3, h: number?)
	local th = h or 6
	solid(parent, "TikiTorchPole", V(0.45, th, 0.45), CF(pos + V(0, th / 2, 0)), C(185, 150, 90), M.Wood)
	vcyl(parent, "TikiTorchBasket", 0.9, 0.95, CF(pos + V(0, th + 0.35, 0)), STRAW, M.Grass)
	local flame = ball(parent, "TikiFlame", 0.85, CF(pos + V(0, th + 1.15, 0)), C(255, 150, 40), M.Neon)
	light(flame, C(255, 160, 70), 14, 0.9)
end

local function sandcastle(parent: Instance, cf: CFrame)
	solid(parent, "Sandcastle", V(4, 1.2, 4), cf * CF(0, 0.6, 0), DRY_SAND, M.Sand)
	vcyl(parent, "SandcastleKeep", 2.4, 1.8, cf * CF(0, 2.4, 0), DRY_SAND, M.Sand)
	vcyl(parent, "SandcastleKeepTop", 0.5, 2.2, cf * CF(0, 3.8, 0), DRY_SAND, M.Sand)
	for _, sx in { -1, 1 } do
		vcyl(parent, "SandcastleTurret", 1.6, 1.1, cf * CF(sx * 1.7, 2, -sx * 1.7), DRY_SAND, M.Sand)
	end
	deco(parent, "SandcastleFlagPole", V(0.1, 1.6, 0.1), cf * CF(0, 4.8, 0), WHITE)
	deco(parent, "SandcastleFlag", V(0.08, 0.6, 0.9), cf * CF(0, 5.3, -0.45), CORAL)
end

local function beachBall(parent: Instance, pos: Vector3, a: Color3, b: Color3)
	ball(parent, "BeachBall", 1.6, CF(pos + V(0, 0.8, 0)), WHITE)
	cyl(parent, "BeachBallBand", V(0.5, 1.64, 1.64), CF(pos + V(0, 0.8, 0)) * ry(30) * rz(25), if rnd() < 0.5 then a else b)
end

local function buoy(parent: Instance, pos: Vector3, color: Color3, name: string?)
	local nm = name or "Buoy"
	vcyl(parent, nm, 1.6, 1.8, CF(pos + V(0, 0.4, 0)), color)
	vcyl(parent, nm .. "Band", 0.5, 1.85, CF(pos + V(0, 0.6, 0)), WHITE)
	local lamp = ball(parent, nm .. "Light", 0.8, CF(pos + V(0, 1.5, 0)), C(255, 230, 120), M.Neon)
	light(lamp, C(255, 220, 120), 8, 0.5)
end

-- Rowboat; bow toward cf's -Z, cf at the waterline.
local function rowboat(parent: Instance, cf: CFrame, hull: Color3, trim: Color3, k: number?)
	local s = k or 1
	deco(parent, "BoatBottom", V(2.6 * s, 0.4 * s, 5.4 * s), cf * CF(0, 0.2 * s, 0.4 * s), hull)
	for _, sx in { -1, 1 } do
		deco(parent, "BoatSide", V(0.3 * s, 1.1 * s, 5.4 * s), cf * CF(sx * 1.3 * s, 0.75 * s, 0.4 * s), hull)
		deco(parent, "Oar", V(0.2 * s, 0.2 * s, 4.4 * s), cf * CF(sx * 1.6 * s, 1.1 * s, 0.4 * s) * ry(sx * 10), DECK_LIGHT, M.Wood)
	end
	deco(parent, "BoatStern", V(2.6 * s, 1.1 * s, 0.3 * s), cf * CF(0, 0.75 * s, 3.1 * s), hull)
	triangle(parent, "BoatBow", 1.45 * s, 2.2 * s, 1.3 * s, cf * CF(0, 0.75 * s, -3.4 * s) * rx(-90), hull)
	deco(parent, "BoatTrim", V(2.9 * s, 0.2 * s, 5.5 * s), cf * CF(0, 1.35 * s, 0.4 * s), trim)
	deco(parent, "BoatSeat", V(2.4 * s, 0.2 * s, 0.8 * s), cf * CF(0, 0.9 * s, 0.6 * s), DECK_LIGHT, M.Wood)
end

-- Sailboat; bow toward cf's -Z, cf at the waterline.
local function sailboat(parent: Instance, cf: CFrame, hull: Color3, sail: Color3, k: number)
	deco(parent, "SailboatHull", V(4 * k, 1.8 * k, 12 * k), cf * CF(0, 0.5 * k, 1 * k), hull)
	triangle(parent, "SailboatBow", 2 * k, 4 * k, 1.8 * k, cf * CF(0, 0.5 * k, -7 * k) * rx(-90), hull)
	deco(parent, "SailboatStripe", V(4.1 * k, 0.35 * k, 12.1 * k), cf * CF(0, 1.1 * k, 1 * k), SEA_BLUE)
	deco(parent, "SailboatDeck", V(3.6 * k, 0.2 * k, 11 * k), cf * CF(0, 1.45 * k, 1 * k), DECK_LIGHT, M.WoodPlanks)
	vcyl(parent, "SailboatMast", 15 * k, 0.4 * k, cf * CF(0, 9 * k, -1 * k), WHITE)
	-- Mainsail behind the mast (tall edge on the mast), jib in front.
	wedge(parent, "Mainsail", V(0.15 * k, 12 * k, 7 * k), cf * CF(0, 8 * k, 2.6 * k) * ry(180), sail, M.Fabric)
	wedge(parent, "Jib", V(0.15 * k, 10 * k, 5 * k), cf * CF(0, 7 * k, -3.6 * k), WHITE, M.Fabric)
	deco(parent, "SailboatFlag", V(0.1 * k, 0.8 * k, 1.4 * k), cf * CF(0, 16.8 * k, -0.3 * k), CORAL)
end

local function yacht(parent: Instance, cf: CFrame)
	deco(parent, "YachtHull", V(8, 3, 24), cf * CF(0, 0.8, 2), WHITE)
	triangle(parent, "YachtBow", 4, 8, 3, cf * CF(0, 0.8, -14) * rx(-90), WHITE)
	deco(parent, "YachtStripe", V(8.1, 0.5, 24.1), cf * CF(0, 0.6, 2), C(20, 40, 90))
	deco(parent, "YachtDeck", V(7.4, 0.2, 23), cf * CF(0, 2.35, 2), DECK_LIGHT, M.WoodPlanks)
	deco(parent, "YachtCabin", V(6, 2.6, 12), cf * CF(0, 3.7, 3), WHITE)
	glass(parent, "YachtWindows", V(6.1, 0.9, 10), cf * CF(0, 3.9, 3), C(40, 60, 90))
	deco(parent, "YachtBridge", V(5, 1.8, 6), cf * CF(0, 5.9, 4), WHITE)
	glass(parent, "YachtBridgeGlass", V(5.1, 0.7, 4.6), cf * CF(0, 6.1, 3.6), C(40, 60, 90))
	deco(parent, "YachtRoof", V(5.6, 0.25, 7), cf * CF(0, 6.9, 4), WHITE)
	vcyl(parent, "YachtMast", 3.5, 0.3, cf * CF(0, 8.6, 5.5), WHITE)
	deco(parent, "YachtRadar", V(2, 0.2, 0.4), cf * CF(0, 10.2, 5.5), C(60, 60, 70))
	deco(parent, "YachtRail", V(0.15, 0.15, 22), cf * CF(-3.7, 3.4, 2), C(200, 200, 205), M.Metal)
	deco(parent, "YachtRail", V(0.15, 0.15, 22), cf * CF(3.7, 3.4, 2), C(200, 200, 205), M.Metal)
	deco(parent, "YachtFlag", V(0.1, 0.8, 1.3), cf * CF(0, 4.6, 14.6), CORAL)
end

-- Lifeguard tower; cf at ground, the lookout faces cf's -Z.
local function lifeguardTower(parent: Instance, cf: CFrame)
	local red = C(225, 45, 45)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			solid(parent, "TowerLeg", V(0.5, 7, 0.5), cf * CF(sx * 2, 3.5, sz * 2) * rz(-sx * 4), WHITE, M.Wood)
		end
	end
	solid(parent, "TowerPlatform", V(5.6, 0.4, 5.6), cf * CF(0, 7.2, 0), DECK, M.WoodPlanks)
	solid(parent, "TowerHut", V(4.4, 3.2, 3.2), cf * CF(0, 9, -0.4), WHITE, M.WoodPlanks)
	deco(parent, "TowerHutBand", V(4.5, 0.7, 3.3), cf * CF(0, 8.2, -0.4), red)
	deco(parent, "TowerWindow", V(3.4, 1.2, 0.1), cf * CF(0, 9.25, -2.05), C(40, 60, 80))
	deco(parent, "TowerRoof", V(5.8, 0.4, 5.2), cf * CF(0, 10.9, -0.4) * rx(6), red)
	-- Railing round the front of the platform.
	deco(parent, "TowerRail", V(5.6, 0.25, 0.25), cf * CF(0, 8.6, -2.7), WHITE)
	for _, sx in { -1, 1 } do
		deco(parent, "TowerRailPost", V(0.25, 1.4, 0.25), cf * CF(sx * 2.7, 8.1, -2.7), WHITE)
	end
	-- Ladder up the back.
	for _, sx in { -1, 1 } do
		deco(parent, "TowerLadderRail", V(0.25, 8.2, 0.25), cf * CF(sx * 0.9, 3.6, 4.4) * rx(-28), WHITE, M.Wood)
	end
	for i = 1, 3 do
		local t = i / 4
		deco(parent, "TowerLadderRung", V(1.8, 0.2, 0.5), cf * CF(0, 7.2 * t, 6.3 - 3.8 * t), DECK_LIGHT, M.Wood)
	end
	-- Flag and life ring.
	deco(parent, "TowerFlagPole", V(0.2, 5, 0.2), cf * CF(2.4, 13.2, 2.4), WHITE, M.Metal)
	deco(parent, "TowerFlag", V(0.1, 1.2, 2), cf * CF(2.4, 15, 1.35), red)
	cyl(parent, "LifeRing", V(0.4, 2.2, 2.2), cf * CF(-2.45, 9, -0.4), ORANGE)
	cyl(parent, "LifeRingHole", V(0.45, 1.1, 1.1), cf * CF(-2.5, 9, -0.4), WHITE)
	sign(parent, "LifeguardSign", V(4.4, 0.7, 0.2), cf * CF(0, 10.25, -2.15), red, "LIFEGUARD", WHITE, C(110, 10, 10), nil, FONT, true)
end

-- Big cartoon fish along cf's +X (head end).
local function bigFish(parent: Instance, cf: CFrame, k: number, body: Color3, belly: Color3, fin: Color3, collide: boolean)
	local function part(name: string, size: Vector3, at: CFrame, color: Color3)
		if collide then
			solid(parent, name, size, at, color)
		else
			deco(parent, name, size, at, color)
		end
	end
	part("FishBody", V(6 * k, 3.4 * k, 2.4 * k), cf, body)
	part("FishHead", V(2.4 * k, 2.6 * k, 2 * k), cf * CF(3.9 * k, -0.1 * k, 0), body)
	part("FishTailRoot", V(2 * k, 2 * k, 1.5 * k), cf * CF(-3.8 * k, 0, 0), body)
	deco(parent, "FishBelly", V(5.8 * k, 1 * k, 2.46 * k), cf * CF(0.3 * k, -1.25 * k, 0), belly)
	triangle(parent, "FishTail", 2.2 * k, 2.6 * k, 0.4 * k, cf * CF(-6 * k, 0, 0) * rz(-90), fin)
	triangle(parent, "FishFin", 1.6 * k, 1.8 * k, 0.3 * k, cf * CF(-0.4 * k, 2.5 * k, 0), fin)
	for _, sz in { -1, 1 } do
		ball(parent, "FishEye", 0.9 * k, cf * CF(4.2 * k, 0.4 * k, sz * 0.9 * k), WHITE)
		ball(parent, "FishPupil", 0.45 * k, cf * CF(4.35 * k, 0.45 * k, sz * 1.25 * k), BLACK)
	end
end

-- Thatched "fringe" skirt hanging below a roof edge on all four sides.
local function thatchSkirt(parent: Instance, bcf: CFrame, w: number, d: number, y: number, drop: number)
	deco(parent, "ThatchSkirt", V(w + 1.6, drop, 0.5), bcf * CF(0, y, -d / 2 - 0.6), STRAW, M.Grass)
	deco(parent, "ThatchSkirt", V(w + 1.6, drop, 0.5), bcf * CF(0, y, d / 2 + 0.6), STRAW, M.Grass)
	deco(parent, "ThatchSkirt", V(0.5, drop, d + 1.6), bcf * CF(-w / 2 - 0.6, y, 0), STRAW, M.Grass)
	deco(parent, "ThatchSkirt", V(0.5, drop, d + 1.6), bcf * CF(w / 2 + 0.6, y, 0), STRAW, M.Grass)
end

-- Tiki mask on a face (u across, v = centre height), facing the face's -Z.
local function tikiMask(parent: Instance, face: CFrame, u: number, v: number, color: Color3)
	local f = face * CF(u, v, -0.45)
	deco(parent, "TikiMask", V(2.4, 4, 0.6), f, color, M.Wood)
	for _, sx in { -1, 1 } do
		deco(parent, "TikiEye", V(0.7, 0.5, 0.15), f * CF(sx * 0.55, 0.8, -0.35), WHITE)
	end
	deco(parent, "TikiBrow", V(2.0, 0.35, 0.2), f * CF(0, 1.35, -0.35), SUNNY)
	deco(parent, "TikiMouth", V(1.4, 0.5, 0.15), f * CF(0, -0.9, -0.35), CORAL)
end

-- Hibiscus flower (crossed petals round a yellow centre) on a face.
local function hibiscus(parent: Instance, face: CFrame, u: number, v: number, color: Color3)
	local f = face * CF(u, v, -0.15)
	deco(parent, "Petals", V(1.9, 0.8, 0.1), f * rz(20), color)
	deco(parent, "Petals", V(0.8, 1.9, 0.1), f * rz(20), color)
	deco(parent, "PetalCentre", V(0.3, 0.3, 0.15), f * CF(0, 0, -0.05), SUNNY)
end

-- Wooden crate (collidable), optionally with fish on top.
local function crate(parent: Instance, cf: CFrame, fish: boolean?)
	solid(parent, "Crate", V(2.6, 1.6, 2), cf * CF(0, 0.8, 0), DECK_LIGHT, M.WoodPlanks)
	deco(parent, "CrateSlat", V(2.65, 0.3, 2.05), cf * CF(0, 1.2, 0), DECK_DARK, M.Wood)
	if fish then
		for i = -1, 1, 2 do
			deco(parent, "CrateFish", V(1.6, 0.4, 0.5), cf * CF(0, 1.75, i * 0.4) * ry(i * 12), C(150, 175, 200), M.Foil)
		end
	end
end

local function beachShower(parent: Instance, pos: Vector3)
	flat(parent, "ShowerGrate", V(2.4, 0.08, 2.4), CF(pos + V(0, 0.04, 0)), DECK_DARK, M.WoodPlanks)
	vcyl(parent, "ShowerPole", 7, 0.4, CF(pos + V(0, 3.5, 0)), C(200, 200, 205), M.Metal, true)
	deco(parent, "ShowerArm", V(0.25, 0.25, 1.4), CF(pos + V(0, 6.9, -0.6)), C(200, 200, 205), M.Metal)
	vcyl(parent, "ShowerHead", 0.3, 0.9, CF(pos + V(0, 6.75, -1.2)), C(200, 200, 205), M.Metal)
end

-- Barrel bin.
local function beachBin(parent: Instance, pos: Vector3, band: Color3)
	vcyl(parent, "BeachBin", 2.4, 1.7, CF(pos + V(0, 1.2, 0)), DECK, M.WoodPlanks, true)
	vcyl(parent, "BeachBinBand", 0.3, 1.8, CF(pos + V(0, 1.9, 0)), band)
	vcyl(parent, "BeachBinBand", 0.3, 1.8, CF(pos + V(0, 0.5, 0)), band)
end

-- Roof-top scenery shared by several shops -----------------------------------

local function giantBurger(f: Instance, L: (number, number, number) -> CFrame, bx: number, bz: number, h: number)
	local bun = C(225, 160, 80)
	vcyl(f, "BurgerBunBottom", 2.2, 11, L(bx, h + 1.1, bz), bun, M.SmoothPlastic, true)
	vcyl(f, "BurgerPatty", 2, 11.6, L(bx, h + 3.2, bz), C(110, 60, 35), M.SmoothPlastic, true)
	deco(f, "BurgerCheese", V(11, 0.4, 11), L(bx, h + 4.4, bz) * ry(45), C(255, 205, 40))
	vcyl(f, "BurgerLettuce", 0.6, 12.4, L(bx, h + 4.9, bz), C(100, 195, 60), M.SmoothPlastic, true)
	vcyl(f, "BurgerTomato", 0.8, 10.8, L(bx, h + 5.6, bz), C(230, 50, 40), M.SmoothPlastic, true)
	vcyl(f, "BurgerBunTop", 2, 11, L(bx, h + 7, bz), bun, M.SmoothPlastic, true)
	vcyl(f, "BurgerBunTop", 1.4, 9.6, L(bx, h + 8.7, bz), bun, M.SmoothPlastic, true)
	vcyl(f, "BurgerBunTop", 1, 7, L(bx, h + 9.9, bz), bun, M.SmoothPlastic, true)
	for i, p in { { -3, 9.45, 1.5 }, { 2.5, 9.45, -2 }, { 1, 10.45, 2 }, { -2, 10.45, -1.5 }, { 3.6, 8.05, 3 } } do
		deco(f, "Sesame" .. i, V(0.9, 0.3, 0.5), L(bx + p[1], h + p[2], bz + p[3]) * ry(i * 37), C(255, 245, 220))
	end
end

-- Shop extras (local frame: X across the front, -Z = street, y from ground) --
-- Each rooftop-food shop keeps its roof props on the half away from the stand
-- (stand at local (±7, 7)), so the stand has headroom and standing room.

local function sushiDockExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Thatched eave flush with the roof (non-colliding: the stairs climb the
	-- west wall under its overhang).
	deco(f, "ThatchEave", V(34, 0.6, 34), L(0, h - 0.32, 0), STRAW, M.Grass)
	deco(f, "ThatchEaveTrim", V(34.3, 0.3, 34.3), L(0, h - 0.65, 0), C(230, 60, 50))
	thatchSkirt(f, bcf, 32.4, 32.4, h - 1.3, 1.2)
	-- Giant tuna leaping over the east half of the roof, plus a giant nigiri.
	bigFish(f, L(7.5, h + 4, -6) * rz(12), 1.1, C(60, 90, 160), C(220, 230, 240), C(250, 200, 60), true)
	solid(f, "FishPlinth", V(4, 2.2, 3), L(7.5, h + 1.1, -6), DECK_DARK, M.WoodPlanks)
	solid(f, "NigiriRice", V(7, 2.4, 4), L(9, h + 1.2, 7), C(250, 250, 245))
	solid(f, "NigiriSalmon", V(7.6, 1, 4.6), L(9, h + 2.9, 7), C(255, 130, 90))
	for k = -1, 1 do
		deco(f, "NigiriStripe", V(0.45, 1.06, 4.66), L(9 + k * 2, h + 2.9, 7), C(255, 220, 200))
	end
	-- Fishing net with floats draped across the front wall.
	local front = faceCF(bcf, b.w, b.d, "front")
	local east = faceCF(bcf, b.w, b.d, "right")
	local net = deco(f, "FishingNet", V(14, 3.2, 0.1), east * CF(0, 9.5, -0.35), C(60, 70, 60), M.Fabric)
	net.Transparency = 0.45
	for i, u in { -5.5, -2, 2, 5.5 } do
		ball(f, "NetFloat", 0.8, east * CF(u, 11.1 - (i % 2) * 0.4, -0.5), if i % 2 == 0 then ORANGE else WHITE)
	end
	-- Paper lanterns at the corners and by the door.
	for _, spot in { { -14, 10.4, -17.2 }, { 14, 10.4, -17.2 }, { -4.2, 6.5, -15.9 }, { 4.2, 6.5, -15.9 } } do
		local lc = L(spot[1], spot[2], spot[3])
		local lantern = ball(f, "Lantern", 2.2, lc, C(230, 60, 50))
		light(lantern, C(255, 140, 90), 12, 0.8)
		vcyl(f, "LanternCap", 0.3, 1.2, lc * CF(0, 1.1, 0), BLACK)
	end
	-- Noren curtain over the door.
	for k = -1, 1 do
		deco(f, "Noren", V(1.4, 2.4, 0.1), front * CF(k * 1.5, 6.6, -0.55), C(30, 60, 110))
	end
	-- Dock pilings with rope, fish crates and a menu board out front.
	for _, u in { -13.5, 13.5 } do
		vcyl(f, "DockPiling", 4, 1.3, L(u, 2, -16.5), DRIFTWOOD, M.Wood, true)
		vcyl(f, "PilingRope", 0.5, 1.45, L(u, 3, -16.5), STRAW, M.Fabric)
	end
	crate(f, L(-9.5, 0.4, -17.5), true)
	crate(f, L(-9.5, 2.0, -17.5) * ry(8), false)
	K.aFrame(f, "SushiMenu", L(-6, 0.4, -21), "SUSHI\nMAKI ROLLS\nNIGIRI")
	seagull(f, L(10, h + 3.4, 7) * ry(200))
end

local function burgerShackExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant burger on the street half away from the stand (stand at local (7, 7)).
	giantBurger(f, L, -6, 2, h)
	-- Little cocktail umbrella stuck in the bun (a fruit-juice umbrella).
	deco(f, "BurgerPick", V(0.25, 5, 0.25), L(-6, h + 12.5, 2), WHITE)
	vcyl(f, "BurgerPickUmbrella", 0.3, 3.4, L(-6, h + 15, 2) * rz(10), HIBISCUS)
	vcyl(f, "BurgerPickUmbrellaTop", 0.35, 1.6, L(-6, h + 15.3, 2) * rz(10), SUNNY)
	-- Surfboards leaning on the front wall, picnic tables and menu.
	local front = faceCF(bcf, b.w, b.d, "front")
	standingBoard(f, front * CF(-12.5, 0.4, -1.6) * rx(10), 7, TURQ, WHITE)
	standingBoard(f, front * CF(12.5, 0.4, -1.6) * rx(10), 7, SUNNY, CORAL)
	for _, u in { -10, -1 } do
		K.cafeTable(f, L(u, 0.4, -24), TURQ, { TURQ, WHITE })
	end
	K.aFrame(f, "BurgerMenu", L(5.5, 0.4, -20.5), "BURGERS\nFRIES\nSHAKES")
	for _, u in { -14, 14 } do
		tikiTorch(f, (L(u, 0.4, -17)).Position, 5)
	end
	seagull(f, L(-6, h + 10.4, 2) * ry(70))
end

local function pokeExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant poke bowl on the west half (stand at local (7, 7)).
	local bx, bz = -6.5, 1
	vcyl(f, "PokeBowlFoot", 1, 6, L(bx, h + 0.5, bz), WHITE, M.SmoothPlastic, true)
	vcyl(f, "PokeBowl", 2, 10, L(bx, h + 2, bz), C(40, 110, 200), M.SmoothPlastic, true)
	vcyl(f, "PokeBowlRim", 1.4, 12, L(bx, h + 3.7, bz), C(40, 110, 200), M.SmoothPlastic, true)
	vcyl(f, "PokeBowlBand", 0.4, 12.1, L(bx, h + 3.2, bz), WHITE)
	vcyl(f, "PokeRice", 0.3, 11.2, L(bx, h + 4.5, bz), C(250, 250, 245))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local cx, cz = math.cos(a) * 3, math.sin(a) * 3
		if i % 3 == 0 then
			deco(f, "PokeSalmon", V(1.4, 1, 1.4), L(bx + cx, h + 5.1, bz + cz) * ry(i * 20), C(255, 120, 90))
		elseif i % 3 == 1 then
			deco(f, "PokeTuna", V(1.4, 1, 1.4), L(bx + cx, h + 5.1, bz + cz) * ry(i * 20), C(210, 50, 70))
		else
			deco(f, "PokeAvocado", V(2, 0.5, 0.9), L(bx + cx, h + 4.9, bz + cz) * ry(i * 40), C(170, 210, 90))
		end
	end
	for i = 0, 3 do
		ball(f, "Edamame", 0.8, L(bx - 0.8 + i * 0.6, h + 5, bz + 0.6 - (i % 2) * 1.2), C(120, 200, 80))
	end
	vcyl(f, "PokeMango", 0.4, 1.4, L(bx, h + 4.9, bz), C(255, 180, 40))
	for k = 0, 1 do
		deco(f, "Chopstick", V(0.45, 0.45, 12), L(bx + 3 + k * 1.2, h + 7, bz - 1) * rx(-35) * ry(-15), C(220, 180, 120), M.Wood)
	end
	-- Hibiscus flowers and tiki torches across the storefront, menu board.
	local front = faceCF(bcf, b.w, b.d, "front")
	for i, u in { -13.4, -10.4, 10.4, 13.4 } do
		hibiscus(f, front, u, 10.8, if i % 2 == 0 then HIBISCUS else ORANGE)
	end
	for _, u in { -14, 14 } do
		tikiTorch(f, (L(u, 0.4, -17)).Position, 5)
	end
	K.aFrame(f, "PokeMenu", L(-5, 0.4, -20.5), "POKE BOWLS\nSALMON\nTUNA")
	K.cafeTable(f, L(8, 0.4, -24), HIBISCUS, { HIBISCUS, SUNNY })
	seagull(f, L(-12, h + 0.2, -12) * ry(160))
end

local function surfBurgerExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- East half (stand at local (-7, 7)): giant shake + giant fries.
	local sx, sz = 7, 0
	vcyl(f, "ShakeCup", 7, 5.6, L(sx, h + 3.5, sz), WHITE, M.SmoothPlastic, true)
	vcyl(f, "ShakeCupBand", 1.6, 5.7, L(sx, h + 3.5, sz), SEA_BLUE)
	vcyl(f, "ShakeCream", 1.2, 5.4, L(sx, h + 7.6, sz), C(255, 240, 230))
	ball(f, "ShakeCreamTop", 3.6, L(sx, h + 8.4, sz), C(255, 240, 230))
	ball(f, "ShakeCherry", 1.2, L(sx, h + 10.4, sz), C(220, 30, 40))
	deco(f, "ShakeStraw", V(0.5, 7, 0.5), L(sx + 1.2, h + 10, sz) * rz(-15), CORAL)
	local fx, fz = 10, -9
	solid(f, "FriesBox", V(4.4, 4, 3), L(fx, h + 2, fz), C(220, 40, 40))
	for i = 0, 6 do
		deco(f, "Fry", V(0.5, 3 + (i % 3) * 0.6, 0.5), L(fx - 1.8 + i * 0.6, h + 5 + (i % 3) * 0.3, fz + (i % 2) * 0.8 - 0.4) * rz((i - 3) * 5), C(255, 215, 70))
	end
	-- Giant surfboard on edge along the street side of the roof.
	surfboard(f, L(-4, h + 1.8, -12) * ry(90) * rz(90), 16, 3.2, SUNNY, SEA_BLUE)
	-- Storefront: surf rack, picnic tables and menu.
	surfRack(f, L(10.5, 0.4, -18.5), 3)
	K.cafeTable(f, L(-7, 0.4, -24), SUNNY, { SEA_BLUE, SUNNY })
	K.aFrame(f, "SurfMenu", L(2.5, 0.4, -20.5), "SURF BURGERS\nFRIES\nSHAKES")
	seagull(f, L(10, h + 4.1, -9) * ry(30))
end

local function tikiExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Pitched thatch roof (collidable wedges inside the 30x30 footprint).
	wedge(f, "ThatchRoof", V(30, 5, 15), L(0, h + 2.5, -7.5), STRAW, M.Grass, true)
	wedge(f, "ThatchRoof", V(30, 5, 15), L(0, h + 2.5, 7.5) * ry(180), STRAW, M.Grass, true)
	deco(f, "ThatchRidge", V(31, 0.8, 1.6), L(0, h + 5, 0), C(190, 150, 85), M.Grass)
	thatchSkirt(f, bcf, 30, 30, h - 0.4, 1.4)
	-- Giant pineapple on the ridge.
	local pc = L(-6, h + 9, 0)
	vcyl(f, "Pineapple", 5, 6, pc, C(245, 185, 40), M.SmoothPlastic, true)
	ball(f, "PineappleTop", 6, pc * CF(0, 2.5, 0), C(245, 185, 40))
	ball(f, "PineappleBottom", 6, pc * CF(0, -2.5, 0), C(245, 185, 40))
	for k = 0, 3 do
		deco(f, "PineappleDiamond", V(6.2, 0.3, 0.3), pc * CF(0, -1.5 + k * 1.2, 0) * ry(k * 45), C(200, 130, 30))
	end
	for k = 0, 5 do
		local a = k * 60
		deco(f, "PineappleLeaf", V(0.9, 4.2, 0.25), pc * CF(0, 6.5, 0) * ry(a) * rx(18) * CF(0, 0, -0.6), C(60, 160, 60))
	end
	-- Giant smoothie with a straw and a paper umbrella.
	local sc = L(7, h + 5.5, 0)
	vcyl(f, "SmoothieCup", 7, 5, sc, C(255, 120, 170), M.Glass, true)
	vcyl(f, "SmoothieLid", 0.5, 5.4, sc * CF(0, 3.7, 0), WHITE)
	deco(f, "SmoothieStraw", V(0.5, 6, 0.5), sc * CF(1, 6, 0) * rz(-12), LIME)
	deco(f, "SmoothieUmbrellaPole", V(0.2, 4, 0.2), sc * CF(-1.2, 5.6, 0) * rz(15), WHITE)
	vcyl(f, "SmoothieUmbrella", 0.3, 3.6, sc * CF(-1.7, 7.5, 0) * rz(15), SUNNY)
	vcyl(f, "SmoothieUmbrellaTop", 0.35, 1.6, sc * CF(-1.75, 7.75, 0) * rz(15), CORAL)
	-- Tiki masks on the front pilasters and bamboo poles by the door.
	local front = faceCF(bcf, b.w, b.d, "front")
	tikiMask(f, front, -13.2, 12.6, C(120, 75, 45))
	tikiMask(f, front, 13.2, 12.6, C(140, 90, 50))
	for _, u in { -14, 14 } do
		tikiTorch(f, (L(u, 0.4, -17.2)).Position, 6)
	end
	K.aFrame(f, "SmoothieMenu", L(-6.5, 0.4, -20.5), "SMOOTHIES\nMANGO\nPINEAPPLE")
	for _, u in { -10, 7 } do
		K.cafeTable(f, L(u, 0.4, -24.5), LIME, { LIME, SUNNY })
	end
end

local function surfShopExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant surfboard standing on the roof, a shark fin and a rooftop sign.
	solid(f, "BoardStand", V(5, 1.2, 3), L(-7, h + 0.6, 5), DECK_DARK, M.WoodPlanks)
	surfboard(f, L(-7, h + 10, 5) * rx(90), 18, 4.4, CORAL, WHITE)
	triangle(f, "SharkFin", 3, 5, 0.6, L(6, h + 2.5, 3) * rz(-14), C(110, 125, 145), M.SmoothPlastic, true)
	sign(f, "RentalSign", V(10, 2.6, 0.4), L(5, h + 2.6, -11), WHITE, "BOARD RENTALS", TURQ, C(0, 70, 90), nil, FONT, true)
	for _, u in { 1, 9 } do
		deco(f, "RentalSignPost", V(0.3, 2.6, 0.3), L(u, h + 1.3, -11), DECK_DARK)
	end
	-- Surf racks, wetsuit rack and a sandwich board out front.
	surfRack(f, L(-9.5, 0.4, -18.5), 3)
	surfRack(f, L(9.5, 0.4, -18.5), 2)
	solid(f, "WetsuitRail", V(0.3, 4.2, 0.3), L(-2.5, 2.5, -21), C(200, 200, 205), M.Metal)
	deco(f, "WetsuitBar", V(4.2, 0.2, 0.2), L(-0.5, 4.5, -21), C(200, 200, 205), M.Metal)
	for i, col in { BLACK, SEA_BLUE, CORAL } do
		deco(f, "Wetsuit", V(1.1, 3, 0.25), L(-1.9 + (i - 1) * 1.3, 2.9, -21), col, M.Fabric)
	end
	K.aFrame(f, "SurfShopBoard", L(3.5, 0.4, -21), "SURF\nLESSONS\nTODAY!")
end

local function iceCreamExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant waffle cone with two scoops and a cherry.
	local cx, cz = -5, 3
	local waffle = C(225, 170, 95)
	for i = 0, 4 do
		vcyl(f, "WaffleCone", 1.8, 1.4 + i * 1.3, L(cx, h + 0.9 + i * 1.8, cz), if i % 2 == 0 then waffle else C(205, 150, 80), M.SmoothPlastic, i < 2)
	end
	ball(f, "Scoop", 6.4, L(cx, h + 10.6, cz), C(255, 170, 200), M.SmoothPlastic, true)
	ball(f, "Scoop", 5.2, L(cx, h + 14.4, cz), C(130, 220, 200), M.SmoothPlastic, true)
	ball(f, "Cherry", 1.4, L(cx, h + 17.4, cz), C(220, 30, 40))
	for i, col in { WHITE, SUNNY, CORAL, LIME, SEA_BLUE } do
		local a = i / 5 * math.pi * 2
		deco(f, "Sprinkle", V(0.7, 0.25, 0.25), L(cx + math.cos(a) * 2.6, h + 13.5, cz + math.sin(a) * 2.6) * ry(i * 50), col)
	end
	-- Giant popsicle on the east half.
	solid(f, "PopsicleStick", V(1.2, 4, 0.6), L(7, h + 2, 4), C(225, 190, 130), M.Wood)
	solid(f, "Popsicle", V(4.4, 7, 1.8), L(7, h + 7.5, 4), ORANGE)
	ball(f, "PopsicleTop", 4.4, L(7, h + 11, 4), ORANGE)
	deco(f, "PopsicleBite", V(1.8, 1.8, 1.9), L(8.6, h + 10.4, 4) * rz(30), C(255, 190, 120))
	-- Sidewalk tables and menu.
	for _, u in { -9, 7 } do
		K.cafeTable(f, L(u, 0.4, -24), C(255, 130, 190), { C(255, 130, 190), WHITE })
	end
	K.aFrame(f, "IceCreamMenu", L(-1.5, 0.4, -20), "ICE CREAM\nSORBET\nSUNDAES")
	local front = faceCF(bcf, b.w, b.d, "front")
	for i, u in { -14.2, 14.2 } do
		hibiscus(f, front, u, 10.8, if i == 1 then HIBISCUS else CORAL)
	end
end

local function fishChipsExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant fish over a basket of chips and a lemon wedge.
	bigFish(f, L(-3, h + 5.4, 3) * rz(-8), 1.2, ORANGE, C(255, 230, 180), CORAL, true)
	solid(f, "FishStand", V(4, 3.4, 3), L(-3, h + 1.7, 3), C(30, 60, 120))
	solid(f, "ChipBasket", V(6, 2.4, 4.4), L(8, h + 1.2, -6), C(200, 40, 40))
	deco(f, "ChipBasketPaper", V(6.2, 0.4, 4.6), L(8, h + 2.6, -6), WHITE)
	for i = 0, 7 do
		deco(f, "Chip", V(0.7, 2.4, 0.7), L(5.8 + (i % 4) * 1.4, h + 3.6, -7 + math.floor(i / 4) * 1.8) * rz((i % 3 - 1) * 12), C(255, 215, 90))
	end
	vcyl(f, "LemonWedge", 0.6, 2.6, L(10.5, h + 3, -3) * rx(70), C(255, 235, 60))
	-- Anchor and life ring on the front wall; crates and lobster traps out front.
	local left = faceCF(bcf, b.w, b.d, "left")
	local right = faceCF(bcf, b.w, b.d, "right")
	local anchor = left * CF(0, 8.4, -0.35)
	deco(f, "Anchor", V(0.5, 3.2, 0.3), anchor, C(40, 50, 70), M.Metal)
	deco(f, "AnchorStock", V(2, 0.4, 0.3), anchor * CF(0, 1.2, 0), C(40, 50, 70), M.Metal)
	deco(f, "AnchorArm", V(2.4, 0.4, 0.3), anchor * CF(0, -1.5, 0), C(40, 50, 70), M.Metal)
	cyl(f, "LifeRing", V(0.4, 2.4, 2.4), right * CF(0, 8.4, -0.4) * ry(90), ORANGE)
	cyl(f, "LifeRingHole", V(0.45, 1.2, 1.2), right * CF(0, 8.4, -0.45) * ry(90), WHITE)
	crate(f, L(-12, 0.4, -18), true)
	crate(f, L(12, 0.4, -18), true)
	solid(f, "LobsterTrap", V(3, 1.6, 2), L(-12, 0.4 + 0.8, -21), C(60, 110, 90), M.Fabric).Transparency = 0.2
	K.cafeTable(f, L(7, 0.4, -24.5), C(30, 60, 120), { C(30, 60, 120), WHITE })
	K.aFrame(f, "FishMenu", L(-1.5, 0.4, -20), "FISH & CHIPS\nCLAMS\nFISH TACOS")
	seagull(f, L(6, h + 2.8, -4.5) * ry(-30))
end

-- Shop specs. The four rooftop-food shops keep the City's geometry exactly
-- (30x30x13 at X ±120, Z ±50, same parapet settings); the other four stay
-- inside X ±(55..85), Z ±(35..65).
local SHOPS: { Spec } = {
	{
		name = "SushiDock", x = -120, z = 50, w = 30, d = 30, h = 13,
		wall = C(70, 150, 160), wallMat = M.WoodPlanks, trim = C(245, 240, 225), door = C(90, 60, 40),
		awningColors = { C(230, 60, 50), WHITE },
		sign = "SUSHI DOCK", signBg = C(25, 55, 95), signFg = WHITE, signStroke = C(230, 60, 50), signBorder = C(255, 120, 90),
		font = FONT, noParapet = true, sideRows = { 4.5 }, extras = sushiDockExtras,
	},
	{
		name = "TikiSmoothies", x = -70, z = 50, w = 30, d = 30, h = 16,
		wall = C(150, 98, 58), wallMat = M.WoodPlanks, trim = C(255, 150, 40), door = C(90, 55, 30),
		awningColors = { C(60, 170, 80), C(255, 220, 80) },
		sign = "TIKI SMOOTHIES", signW = 20, signBg = C(50, 140, 70), signFg = C(255, 230, 80), signStroke = C(25, 60, 20), signBorder = C(255, 150, 40),
		font = FONT, sideRows = { 4.5 }, extras = tikiExtras,
	},
	{
		name = "IceCreamHut", x = 70, z = 50, w = 30, d = 30, h = 13,
		wall = C(255, 195, 215), wallMat = M.Plaster, trim = WHITE, door = C(150, 95, 60),
		awningColors = { C(255, 130, 190), WHITE },
		sign = "ICE CREAM HUT", signBg = C(255, 250, 240), signFg = C(240, 80, 150), signStroke = C(120, 60, 40), signBorder = C(255, 130, 190),
		font = FONT, sideRows = { 4.5 }, extras = iceCreamExtras,
	},
	{
		name = "PokeShack", x = 120, z = 50, w = 30, d = 30, h = 13,
		wall = C(130, 220, 200), wallMat = M.WoodPlanks, trim = C(255, 110, 150), door = C(255, 110, 150),
		awningColors = { C(255, 110, 150), WHITE },
		sign = "ALOHA POKE", signW = 16, signBg = C(255, 110, 150), signFg = WHITE, signStroke = C(130, 20, 60), signBorder = C(255, 220, 80),
		font = FONT, sideRows = { 4.5 }, sideGap = { 1, 4.6, 9.6 }, extras = pokeExtras,
	},
	{
		name = "BurgerShack", x = -120, z = -50, w = 30, d = 30, h = 13,
		wall = C(255, 175, 125), wallMat = M.WoodPlanks, trim = WHITE, door = C(0, 170, 190),
		awningColors = { C(0, 180, 200), WHITE },
		sign = "BURGER SHACK", signU = -4, signW = 18, signBg = C(0, 170, 190), signFg = C(255, 235, 80),
		signStroke = C(0, 70, 90), signBorder = C(255, 220, 80), font = FONT,
		sideGap = { 1, 4.6, 9.6 }, sideRows = { 4.5 }, extras = burgerShackExtras,
	},
	{
		name = "SurfShop", x = -70, z = -50, w = 30, d = 30, h = 14,
		wall = C(255, 125, 105), wallMat = M.Plaster, trim = WHITE, door = C(0, 180, 200),
		awningColors = { C(0, 180, 200), WHITE },
		sign = "SURF SHOP", signBg = C(0, 180, 200), signFg = WHITE, signStroke = C(0, 80, 100), signBorder = C(255, 240, 120),
		font = FONT, sideRows = { 4.5 }, extras = surfShopExtras,
	},
	{
		name = "FishAndChips", x = 70, z = -50, w = 30, d = 30, h = 12,
		wall = C(250, 250, 245), wallMat = M.WoodPlanks, trim = C(30, 60, 120), door = C(30, 60, 120),
		awningColors = { C(30, 60, 120), WHITE },
		sign = "FISH & CHIPS", signBg = C(30, 60, 120), signFg = C(255, 220, 80), signStroke = C(10, 20, 50), signBorder = C(255, 220, 80),
		font = FONT, sideRows = { 4.5 }, extras = fishChipsExtras,
	},
	{
		name = "SurfBurgers", x = 120, z = -50, w = 30, d = 30, h = 13,
		wall = C(60, 135, 220), wallMat = M.WoodPlanks, trim = WHITE, door = C(255, 200, 40),
		awningColors = { C(255, 200, 40), C(60, 135, 220) },
		sign = "SURF BURGERS", signW = 18, signBg = C(255, 200, 40), signFg = C(30, 80, 180), signStroke = WHITE, signBorder = C(80, 220, 255),
		font = FONT, sideRows = { 4.5 }, sideGap = { -1, 4.6, 9.6 }, extras = surfBurgerExtras,
	},
}

local function buildShops(root: Instance)
	local shops = newFolder(root, "Shops")
	for _, b in SHOPS do
		local f, bcf = K.buildShop(shops, b)
		-- Striped awning (wider stripes than buildShop's built-in one).
		awning(f, "Awning", faceCF(bcf, b.w, b.d, "front"), 0, 8.4, b.w - 2, 3.6, 1.3, b.awningColors, 3.5)
		-- Beach-style recolour of the generic concrete bits buildShop adds.
		for _, c in f:GetChildren() do
			if c:IsA("BasePart") then
				if c.Name == "Plinth" then
					c.Color = C(215, 195, 160)
					c.Material = M.Sandstone
				elseif c.Name == "RoofCap" then
					c.Color = C(200, 185, 160)
					c.Material = M.Sandstone
				elseif c.Name == "BackStep" then
					c.Color = DECK
					c.Material = M.WoodPlanks
				elseif c.Name == "BackDoor" then
					c.Color = DECK_DARK
					c.Material = M.WoodPlanks
				end
			end
		end
	end
end

-- Boundary, ground and boardwalks --------------------------------------------

local function buildBoundary(root: Instance, m: { [string]: any })
	local f = newFolder(root, "Boundary")
	local wallHeight: number = m.wallHeight or 20
	local L2, W2 = m.fieldLength / 2, m.fieldWidth / 2
	-- Invisible full-height walls (the contract) so the ocean stays in view.
	local walls: { { name: string, size: Vector3, cf: CFrame } } = {
		{ name = "WallNorth", size = V(m.fieldLength, wallHeight, 2), cf = CF(0, wallHeight / 2, W2) },
		{ name = "WallSouth", size = V(m.fieldLength, wallHeight, 2), cf = CF(0, wallHeight / 2, -W2) },
		{ name = "WallEast", size = V(2, wallHeight, m.fieldWidth), cf = CF(L2, wallHeight / 2, 0) },
		{ name = "WallWest", size = V(2, wallHeight, m.fieldWidth), cf = CF(-L2, wallHeight / 2, 0) },
	}
	for _, w in walls do
		local p = solid(f, w.name, w.size, w.cf, C(200, 230, 255))
		p.Transparency = 1
		p.CastShadow = false
	end
	-- Visible low sea wall (coral stone) with a white railing on top.
	local stone = C(232, 214, 178)
	solid(f, "SeaWall", V(m.fieldLength, 2.4, 1.4), CF(0, 1.2, W2 - 0.7), stone, M.Sandstone)
	solid(f, "SeaWall", V(m.fieldLength, 2.4, 1.4), CF(0, 1.2, -W2 + 0.7), stone, M.Sandstone)
	solid(f, "SeaWall", V(1.4, 2.4, m.fieldWidth), CF(L2 - 0.7, 1.2, 0), stone, M.Sandstone)
	solid(f, "SeaWall", V(1.4, 2.4, m.fieldWidth), CF(-L2 + 0.7, 1.2, 0), stone, M.Sandstone)
	deco(f, "SeaWallTop", V(m.fieldLength + 1, 0.3, 1.8), CF(0, 2.55, W2 - 0.7), WHITE, M.Concrete)
	deco(f, "SeaWallTop", V(m.fieldLength + 1, 0.3, 1.8), CF(0, 2.55, -W2 + 0.7), WHITE, M.Concrete)
	deco(f, "SeaWallTop", V(1.8, 0.3, m.fieldWidth + 1), CF(L2 - 0.7, 2.55, 0), WHITE, M.Concrete)
	deco(f, "SeaWallTop", V(1.8, 0.3, m.fieldWidth + 1), CF(-L2 + 0.7, 2.55, 0), WHITE, M.Concrete)
	local railY = 4.6
	for _, zs in { -1, 1 } do
		local z = zs * (W2 - 0.7)
		deco(f, "SeaRail", V(m.fieldLength, 0.3, 0.3), CF(0, railY, z), WHITE, M.Metal)
		deco(f, "SeaRail", V(m.fieldLength, 0.2, 0.2), CF(0, railY - 1, z), WHITE, M.Metal)
		for x = -192, 192, 32 do
			deco(f, "SeaRailPost", V(0.35, 2.2, 0.35), CF(x, 3.7, z), WHITE, M.Metal)
		end
		for _, x in { -110, 70 } do
			local r = CF(x + zs * 10, 3.6, z - zs * 0.45)
			cyl(f, "LifeRing", V(0.4, 2.4, 2.4), r * ry(90), ORANGE)
			cyl(f, "LifeRingHole", V(0.45, 1.2, 1.2), r * ry(90), stone)
		end
	end
	for _, xs in { -1, 1 } do
		local x = xs * (L2 - 0.7)
		deco(f, "SeaRail", V(0.3, 0.3, m.fieldWidth), CF(x, railY, 0), WHITE, M.Metal)
		deco(f, "SeaRail", V(0.2, 0.2, m.fieldWidth), CF(x, railY - 1, 0), WHITE, M.Metal)
		for z = -80, 80, 32 do
			deco(f, "SeaRailPost", V(0.35, 2.2, 0.35), CF(x, 3.7, z), WHITE, M.Metal)
		end
	end
end

local function buildGround(root: Instance, m: { [string]: any })
	local L2 = m.fieldLength / 2
	solid(root, "Ground", V(m.fieldLength, 1, m.fieldWidth), CF(0, -0.5, 0), SAND, M.Sand)
	-- Team floors: wooden decks in the team colours' tint.
	solid(root, "RedBaseFloor", V(40, 0.2, m.fieldWidth), CF(-L2 + 20, 0.1, 0), C(190, 120, 90), M.WoodPlanks)
	solid(root, "BlueBaseFloor", V(40, 0.2, m.fieldWidth), CF(L2 - 20, 0.1, 0), C(120, 140, 175), M.WoodPlanks)
	local f = newFolder(root, "BaseDecks")
	for _, xs in { -1, 1 } do
		local cx = xs * (L2 - 20)
		-- Plank seams and a trim board along the field edge of each deck.
		for z = -72, 72, 24 do
			flat(f, "DeckSeam", V(39.6, 0.04, 0.3), CF(cx, 0.21, z), DECK_DARK)
		end
		flat(f, "DeckTrim", V(0.8, 0.06, m.fieldWidth), CF(xs * (L2 - 40.2), 0.21, 0), C(245, 240, 225))
	end
end

local function buildBoardwalks(root: Instance, m: { [string]: any })
	local f = newFolder(root, "Boardwalks")
	-- Main street boardwalk (the lagoon bridge spans |X| < 38).
	for _, xs in { -1, 1 } do
		solid(f, "Boardwalk", V(122, 0.1, 40), CF(xs * 99, 0.05, 0), DECK, M.WoodPlanks)
		for i = 0, 5 do
			flat(f, "BoardwalkJoist", V(0.4, 0.04, 40), CF(xs * (44 + i * 22), 0.12, 0), DECK_DARK)
		end
		-- Lighter plank bands down both edges of the travelled way.
		for _, zs in { -1, 1 } do
			flat(f, "BoardwalkBand", V(122, 0.04, 2.2), CF(xs * 99, 0.12, zs * 16.5), DECK_LIGHT, M.WoodPlanks)
			solid(f, "BoardwalkEdge", V(122, 0.4, 0.6), CF(xs * 99, 0.2, zs * 20.3), DECK_DARK, M.Wood)
		end
		-- Pilings where the boardwalk meets the lagoon.
		for _, zs in { -1, 1 } do
			for _, x in { 39, 43.5, 48 } do
				vcyl(f, "Piling", 1.4, 0.9, CF(xs * x, 0.5, zs * 20.4), DRIFTWOOD, M.Wood)
			end
		end
	end
	-- Sand drifts blown across the boards (flat, walk-through).
	for _, p in { { -130, 9 }, { -86, -14 }, { -62, 6 }, { 66, -8 }, { 92, 13 }, { 128, -4 }, { 150, 12 }, { -150, -11 } } do
		cyl(f, "SandDrift", V(0.06, 7, 7), CF(p[1], 0.13, p[2]) * UP, DRY_SAND, M.Sand).CastShadow = false
	end
	-- Promenades (sidewalks) Z ±(20..35), pale coral pavers.
	for _, zs in { -1, 1 } do
		for _, xs in { -1, 1 } do
			solid(f, "Promenade", V(110, 0.3, 14.4), CF(xs * 105, 0.15, zs * 27.8), C(245, 228, 196), M.Pavement)
			-- Wooden sun decks on the corner plazas.
			solid(f, "SunDeck", V(23, 0.3, 32), CF(xs * 148.5, 0.15, zs * 51), DECK_LIGHT, M.WoodPlanks)
		end
		-- Back boardwalk Z ±(65..79) (holds the bot lanes and alley dash pads).
		solid(f, "BackBoardwalk", V(320, 0.1, 14), CF(0, 0.05, zs * 72), DECK, M.WoodPlanks)
		for x = -140, 140, 40 do
			flat(f, "BackJoist", V(0.4, 0.04, 14), CF(x, 0.12, zs * 72), DECK_DARK)
		end
		flat(f, "BackBand", V(320, 0.04, 1.2), CF(0, 0.12, zs * 78.2), DECK_LIGHT, M.WoodPlanks)
	end
	-- Canals in the side streets X ±(85..105), Z ±(35..66), with plank edges
	-- and a round deck under each jump pad.
	local pads = { { -91, 50 }, { -91, -50 }, { 99, 50 }, { 99, -50 } }
	for _, zs in { -1, 1 } do
		for _, xs in { -1, 1 } do
			local x1, x2 = xs * 95 - 9, xs * 95 + 9
			local z1, z2 = if zs > 0 then 36 else -66, if zs > 0 then 66 else -36
			local px = if xs > 0 then 99 else -91
			local pz = zs * 50
			flat(f, "CanalBed", V(18, 0.02, 30), CF(xs * 95, 0.02, zs * 51), LAGOON_DEEP, M.Sand)
			waterWithHole(f, "CanalWater", x1, x2, z1, z2, px - 5.5, px + 5.5, pz - 5.5, pz + 5.5, 0.07, LAGOON, 0.35)
			cyl(f, "PadDeck", V(0.08, 11, 11), CF(px, 0.06, pz) * UP, DECK_LIGHT, M.WoodPlanks).CastShadow = false
			for _, ex in { x1 - 0.5, x2 + 0.5 } do
				flat(f, "CanalEdge", V(1, 0.12, 30), CF(ex, 0.06, zs * 51), DECK_DARK, M.Wood)
			end
		end
	end
	for _, p in pads do
		-- Rubber duck floating near each pad (scenery, walk-through).
		local dcf = CF(p[1] + (if p[1] > 0 then -5 else 3), 0, p[2] + (if p[2] > 0 then 10 else -10))
		ball(f, "RubberDuck", 1.8, dcf * CF(0, 0.85, 0), SUNNY)
		ball(f, "RubberDuckHead", 1.2, dcf * CF(0, 2, -0.6), SUNNY)
		deco(f, "RubberDuckBill", V(0.6, 0.25, 0.5), dcf * CF(0, 1.9, -1.3), ORANGE)
	end
	-- Parked beach vans with surfboards on the roof (kerbside, outside |z| < 12).
	local vans: { { x: number, z: number, yaw: number, color: Color3 } } = {
		{ x = 70, z = 16, yaw = 0, color = C(80, 200, 220) },
		{ x = 128, z = -16, yaw = 180, color = ORANGE },
		{ x = -104, z = 16, yaw = 0, color = SUNNY },
	}
	for i, v in vans do
		local cf = CF(v.x, 0.1, v.z) * ry(v.yaw)
		K.car(f, cf, v.color)
		surfboard(f, cf * CF(-0.4, 4.2, 0) * ry(90), 7, 1.8, if i == 2 then TURQ else WHITE, CORAL)
	end
	-- Tiki torches along both promenades and the back boardwalk.
	for _, zs in { -1, 1 } do
		for _, x in { -154, -108, -58, 58, 108, 154 } do
			tikiTorch(f, V(x, 0.3, zs * 21.4))
		end
		for _, x in { -140, -60, 10, 90 } do
			tikiTorch(f, V(zs * x, 0, zs * 79.8), 5)
		end
	end
	-- Beach-flag bunting across the main street.
	for _, xs in { -1, 1 } do
		for _, x in { 66, 120 } do
			for _, zs in { -1, 1 } do
				solid(f, "FlagPole", V(0.5, 13, 0.5), CF(xs * x, 6.5, zs * 21.4), WHITE, M.Metal)
				ball(f, "FlagPoleTop", 0.8, CF(xs * x, 13.2, zs * 21.4), SUNNY)
			end
			K.bunting(f, "BeachFlags", CF(xs * x, 0, 0) * ry(90), -21.2, 12.6, 21.2, 12.6, 0, 9, true)
		end
	end
	-- Bins and outdoor showers.
	for _, p in { V(-60, 0.3, 23.6), V(60, 0.3, -23.6), V(-110, 0.3, -23.6), V(110, 0.3, 23.6) } do
		beachBin(f, p, TURQ)
	end
	for _, p in { V(-30, 0, 86), V(30, 0, -86), V(-150, 0, 86), V(150, 0, -86) } do
		beachBin(f, p, CORAL)
	end
	-- Fish crates and lobster traps behind the shops (outer side of the alley).
	for _, p in { V(-128, 0, 77.5), V(-62, 0, 77.5), V(62, 0, -77.5), V(128, 0, -77.5) } do
		crate(f, CF(p), true)
		crate(f, CF(p + V(1.2, 1.6, 0)) * ry(-5), false)
	end
end

-- Lagoon and bridge -----------------------------------------------------------

local function buildLagoon(root: Instance)
	local f = newFolder(root, "Lagoon")
	local Y = 0.07
	-- Bed, deep patches and water: north + south bays and the middle under the bridge.
	for _, zs in { -1, 1 } do
		flat(f, "LagoonBed", V(100, 0.02, 43), CF(0, 0.02, zs * 41.5), LAGOON_BED, M.Sand)
		for _, xs in { -1, 1 } do
			flat(f, "LagoonDeep", V(24, 0.02, 30), CF(xs * 27, 0.035, zs * 44), LAGOON_DEEP, M.Sand)
		end
		water(f, "LagoonWater", -50, 50, if zs > 0 then 20 else -63, if zs > 0 then 63 else -20, Y, LAGOON, 0.35)
		-- Foam where the water meets the sand, wet sand beyond.
		local foamBack = flat(f, "Foam", V(100, 0.03, 0.8), CF(0, 0.1, zs * 62.6), WHITE)
		foamBack.Transparency = 0.3
		flat(f, "WetSand", V(104, 0.02, 2), CF(0, 0.012, zs * 64), WET_SAND, M.Sand)
		for _, xs in { -1, 1 } do
			local foam = flat(f, "Foam", V(0.8, 0.03, 28), CF(xs * 49.6, 0.1, zs * 49), WHITE)
			foam.Transparency = 0.3
			flat(f, "WetSand", V(2, 0.02, 30), CF(xs * 51.2, 0.012, zs * 50), WET_SAND, M.Sand)
			-- Low rope fence along the promenade edge (walk-through).
			for _, z in { 22, 28, 34 } do
				deco(f, "ShorePost", V(0.4, 2.4, 0.4), CF(xs * 50.4, 1.5, zs * z), DRIFTWOOD, M.Wood)
			end
			deco(f, "ShoreRope", V(0.18, 0.18, 12.4), CF(xs * 50.4, 2.3, zs * 28), STRAW, M.Fabric)
		end
		-- Ripples on the water.
		for i = 1, 4 do
			local r = flat(f, "Ripple", V(rrange(4, 9), 0.02, 0.35), CF(rrange(-40, 40), 0.1, zs * rrange(24, 60)) * ry(rrange(-20, 20)), WHITE)
			r.Transparency = 0.5
		end
	end
	flat(f, "LagoonBed", V(76, 0.02, 40), CF(0, 0.02, 0), LAGOON_BED, M.Sand)
	water(f, "LagoonWater", -38, 38, -20, 20, Y, LAGOON, 0.35)

	-- Sandbars under the burger spawns.
	for _, zs in { -1, 1 } do
		vcyl(f, "BurgerSandbar", 0.1, 10, CF(0, 0.08, zs * 30), DRY_SAND, M.Sand)
	end

	-- North island: palms, hammock, loungers and an umbrella.
	local ni = newFolder(f, "NorthIsland")
	vcyl(ni, "IslandSand", 0.12, 26, CF(0, 0.08, 50), SAND, M.Sand)
	vcyl(ni, "IslandSandTop", 0.1, 19, CF(0, 0.16, 50), DRY_SAND, M.Sand)
	palm(ni, V(-5, 0.2, 55), 13, 160, 3)
	palm(ni, V(5, 0.2, 55), 14, 20, 3)
	palm(ni, V(8, 0.2, 44), 12, -40, 2.5)
	-- Hammock slung between the two back palms.
	deco(ni, "Hammock", V(4.6, 0.15, 1.6), CF(-2.2, 2.4, 55) * rz(-14), CORAL, M.Fabric)
	deco(ni, "Hammock", V(4.6, 0.15, 1.6), CF(2.2, 2.4, 55) * rz(14), CORAL, M.Fabric)
	rope(ni, "HammockRope", CF(0, 0, 55), -4.5, 3.4, -4.3, 2.9, 0, STRAW)
	rope(ni, "HammockRope", CF(0, 0, 55), 4.3, 2.9, 4.5, 3.4, 0, STRAW)
	beachUmbrella(ni, CF(-6, 0.2, 44), UMBRELLAS[2], TOWELS[3])
	lounger(ni, CF(-2.4, 0.2, 43) * ry(180), WHITE)
	sandcastle(ni, CF(3, 0.2, 61) * ry(10))
	starfish(ni, CF(-9, 0.2, 49), CORAL)

	-- South island: beach volleyball.
	local si = newFolder(f, "SouthIsland")
	vcyl(si, "IslandSand", 0.12, 28, CF(0, 0.08, -50), SAND, M.Sand)
	vcyl(si, "IslandSandTop", 0.1, 22, CF(0, 0.16, -50), DRY_SAND, M.Sand)
	for _, x in { -8, 8 } do
		flat(si, "CourtLine", V(0.3, 0.04, 9), CF(x, 0.23, -50), WHITE)
	end
	for _, z in { -54.5, -45.5 } do
		flat(si, "CourtLine", V(16, 0.04, 0.3), CF(0, 0.23, z), WHITE)
	end
	for _, z in { -55.6, -44.4 } do
		solid(si, "VolleyPost", V(0.4, 8, 0.4), CF(0, 4, z), C(240, 240, 240), M.Metal)
	end
	local net = deco(si, "VolleyNet", V(0.08, 2.6, 11), CF(0, 6.4, -50), C(40, 40, 50), M.Fabric)
	net.Transparency = 0.45
	deco(si, "VolleyNetTape", V(0.12, 0.3, 11.2), CF(0, 7.75, -50), WHITE)
	deco(si, "VolleyNetTape", V(0.12, 0.2, 11.2), CF(0, 5.05, -50), WHITE)
	beachBall(si, V(-4, 0.2, -48), SUNNY, SEA_BLUE)
	palm(si, V(-9, 0.2, -41.5), 12, 200, 2.5)
	palm(si, V(9, 0.2, -41.5), 13, -20, 3)
	crab(si, CF(5, 0.2, -59) * ry(30))
	shell(si, CF(-6, 0.2, -59), C(255, 200, 210))

	-- Docks with moored rowboats, floats and a rubber duck.
	for _, zs in { -1, 1 } do
		for _, xs in { -1, 1 } do
			local dx, dz = xs * 44, zs * 45
			solid(f, "LagoonDock", V(12, 0.5, 4), CF(dx, 0.35, dz), DECK, M.WoodPlanks)
			for _, ox in { -5.5, 5.5 } do
				vcyl(f, "DockPost", 2.2, 0.6, CF(dx + ox, 1.1, dz - zs * 2.2), DRIFTWOOD, M.Wood)
			end
			local col = if xs * zs > 0 then CORAL else TURQ
			rowboat(f, CF(dx - xs * 1, 0.05, dz - zs * 4.4) * ry(90), WHITE, col)
		end
	end
	for _, p in { V(-22, 0, 33), V(24, 0, -27), V(-30, 0, -56) } do
		cyl(f, "SwimRing", V(0.5, 3, 3), CF(p + V(0, 0.25, 0)) * UP, ORANGE)
		cyl(f, "SwimRingHole", V(0.55, 1.4, 1.4), CF(p + V(0, 0.25, 0)) * UP, LAGOON)
	end
	-- Buoy line marking the swim area in the north bay.
	for i = 0, 3 do
		buoy(f, V(-21 + i * 14, 0, 37), if i % 2 == 0 then CORAL else WHITE, "SwimBuoy")
	end
	sign(f, "LagoonSign", V(7, 2.4, 0.3), CF(47, 4.6, 36) * ry(-90), WHITE, "LAGOON\nANKLE DEEP!", SEA_BLUE, C(0, 60, 120), nil, FONT, true)
	deco(f, "LagoonSignPost", V(0.35, 4, 0.35), CF(47, 2, 36), DRIFTWOOD, M.Wood)
	-- Rocks and shells along the shore corners.
	for _, p in { V(-48, 0, 62), V(48, 0, 61), V(-47, 0, -62), V(48, 0, -62) } do
		ball(f, "ShoreRock", 2.6, CF(p + V(0, 0.4, 0)), ROCK, M.Rock, true)
		ball(f, "ShoreRock", 1.6, CF(p + V(1.6, 0.2, 0.8)), C(150, 145, 135), M.Rock)
	end
	for i, p in { V(-35, 0, 62.5), V(20, 0, 63.5), V(-15, 0, -63.5), V(38, 0, -63) } do
		shell(f, CF(p) * ry(i * 50), if i % 2 == 0 then C(255, 210, 220) else C(255, 240, 220))
	end
end

-- Wooden boardwalk bridge on the main street (names Bridge*/Ramp* may sit in
-- the main street corridor). Deck top 7, ramps 30 long rising 7.
local function buildBridge(root: Instance)
	local f = newFolder(root, "Bridge")
	local top, rampLen, halfDeck, width = 7, 30, 8, 20
	solid(f, "BridgeDeck", V(halfDeck * 2, 0.8, width), CF(0, top - 0.4, 0), DECK, M.WoodPlanks)
	local rx0 = halfDeck + rampLen / 2
	wedge(f, "RampWest", V(width, top, rampLen), CF(-rx0, top / 2, 0) * ry(90), DECK, M.WoodPlanks, true)
	wedge(f, "RampEast", V(width, top, rampLen), CF(rx0, top / 2, 0) * ry(-90), DECK, M.WoodPlanks, true)
	-- Pilings under the deck and a trim board along the ramp edges.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			vcyl(f, "BridgePiling", top - 0.8, 1, CF(sx * (halfDeck - 0.6), (top - 0.8) / 2, sz * (width / 2 - 0.6)), DRIFTWOOD, M.Wood)
		end
	end
	local slope = math.atan(top / rampLen)
	local slopeLen = math.sqrt(rampLen * rampLen + top * top)
	local railC = WHITE
	for _, zs in { -1, 1 } do
		local z = zs * (width / 2 - 0.2)
		deco(f, "BridgeRail", V(halfDeck * 2, 0.35, 0.35), CF(0, top + 3, z), railC, M.Wood)
		deco(f, "BridgeRail", V(slopeLen, 0.35, 0.35), CF(-rx0, top / 2 + 3, z) * rz(math.deg(slope)), railC, M.Wood)
		deco(f, "BridgeRail", V(slopeLen, 0.35, 0.35), CF(rx0, top / 2 + 3, z) * rz(-math.deg(slope)), railC, M.Wood)
		deco(f, "BridgeRope", V(slopeLen, 0.18, 0.18), CF(-rx0, top / 2 + 1.6, z) * rz(math.deg(slope)), STRAW, M.Fabric)
		deco(f, "BridgeRope", V(slopeLen, 0.18, 0.18), CF(rx0, top / 2 + 1.6, z) * rz(-math.deg(slope)), STRAW, M.Fabric)
		for x = -36, 36, 9 do
			local y = top - math.max(0, math.abs(x) - halfDeck) * top / rampLen
			deco(f, "BridgeRailPost", V(0.4, 3.2, 0.4), CF(x, y + 1.5, z), DECK_LIGHT, M.Wood)
		end
		flat(f, "BridgeTrim", V(halfDeck * 2, 0.1, 0.6), CF(0, top + 0.02, z), DECK_DARK)
	end
	-- WATER WORLD welcome arch: two giant surfboards hold the banner.
	for _, zs in { -1, 1 } do
		local z = zs * 13
		solid(f, "BridgeArchPost", V(0.25, 20, 1.2), CF(0, 10, z), C(240, 240, 240), M.Wood)
		standingBoard(f, CF(0, 0, z) * ry(90), 22, if zs > 0 then CORAL else TURQ, WHITE, 3.4)
	end
	-- Banner board faces along the street both ways (labels front and back).
	sign(f, "BridgeArchBeam", V(29, 3.6, 1.5), CF(0, 19.5, 0) * ry(90), SEA_BLUE, "WATER WORLD", SUNNY, C(0, 60, 140), C(0, 230, 255), FONT, true)
	-- Sun disc and wave crest on top of the banner.
	local sun = cyl(f, "ArchSun", V(0.6, 6, 6), CF(0, 24.2, 0), SUNNY, M.Neon)
	light(sun, C(255, 220, 120), 16, 0.6)
	for i = -3, 3 do
		triangle(f, "ArchWave", 1.2, 1.6, 1.6, CF(0, 21.9, i * 3.8) * ry(90), if i % 2 == 0 then TURQ else WHITE)
	end
	-- Life rings on the deck rails.
	for _, zs in { -1, 1 } do
		cyl(f, "LifeRing", V(0.4, 2.2, 2.2), CF(0, top + 2, zs * (width / 2 + 0.1)) * ry(90), ORANGE)
		cyl(f, "LifeRingHole", V(0.45, 1.1, 1.1), CF(0, top + 2, zs * (width / 2 + 0.15)) * ry(90), WHITE)
	end
end

-- Beach strips, plazas and signage --------------------------------------------

local function buildBeach(root: Instance)
	local f = newFolder(root, "Beach")
	-- North beach strip Z 79..88.5; the south strip is the same rotated 180°.
	for _, zs in { -1, 1 } do
		local s = newFolder(f, if zs > 0 then "NorthBeach" else "SouthBeach")
		local function P(x: number, z: number): CFrame
			return CF(zs * x, 0, zs * z) * (if zs > 0 then CF() else ry(180))
		end
		lifeguardTower(s, P(-20, 84) * ry(180))
		for i, x in { -150, -108, -62, 32, 70, 118 } do
			beachUmbrella(s, P(x, 84), UMBRELLAS[(i - 1) % #UMBRELLAS + 1], TOWELS[(i - 1) % #TOWELS + 1])
			lounger(s, P(x - 3.6, 82.6) * ry(180) * ry(-8), UMBRELLAS[i % #UMBRELLAS + 1][1])
		end
		for i, x in { -135, -40, 140 } do
			palm(s, P(x, 86).Position, 13 + (i % 2) * 2, if zs > 0 then 90 - i * 25 else -90 + i * 25, 3.5)
		end
		sandcastle(s, P(-84, 83.5) * ry(15))
		sandcastle(s, P(98, 84) * ry(-10))
		surfRack(s, P(4, 86), 3)
		for i, x in { -125, -48, 12, 86, 150 } do
			beachBall(s, P(x, 81.5 + (i % 2) * 3).Position, UMBRELLAS[i][1], UMBRELLAS[i % 6 + 1][1])
		end
		for i, x in { -96, 44, 108 } do
			crab(s, P(x, 81 + (i % 3)) * ry(i * 70))
		end
		for i, x in { -75, 128 } do
			starfish(s, P(x, 80.6 + (i % 2) * 6), if i % 2 == 0 then CORAL else C(255, 170, 60))
		end
		for i, x in { -118, 22, 80, 156 } do
			shell(s, P(x, 81.2 + (i % 3) * 2.2) * ry(i * 40), if i % 2 == 0 then C(255, 205, 215) else C(255, 245, 225))
		end
		-- Sea-wall seagulls.
		for _, x in { -160, 64 } do
			seagull(s, P(x, 89.3) * CF(0, 4.85, 0) * ry(170 + x % 40))
		end
	end
end

local function buildPlazas(root: Instance)
	local f = newFolder(root, "Plazas")
	-- Corner sun decks |X| 137..160 (props at |X| >= 146: the rooftop stairs
	-- run along |X| 135..143).
	for _, zs in { -1, 1 } do
		for _, xs in { -1, 1 } do
			local function P(x: number, z: number): CFrame
				return CF(xs * x, 0.3, zs * z)
			end
			palm(f, P(153, 40).Position, 14, if xs > 0 then 0 else 180, 3)
			surfRack(f, P(155.5, 51) * ry(if xs > 0 then -90 else 90), 2)
			beachUmbrella(f, P(150, 61), UMBRELLAS[(xs + zs + 4) % 6 + 1], nil)
			lounger(f, P(153.5, 60) * ry(if xs > 0 then -90 else 90), WHITE)
			beachShower(f, (P(157.5, 64.5)).Position)
		end
	end
	-- Lifeguard towers in the team yards (between the patios and the sea wall).
	-- (Red's on the north side, Blue's on the south: the arena is point-symmetric.)
	lifeguardTower(f, CF(-182, 0.2, 70) * ry(180))
	lifeguardTower(f, CF(182, 0.2, -70))
end

local function buildSignage(root: Instance)
	local f = newFolder(root, "Signs")
	-- Billboards on stilts by the sea wall, facing the field.
	local ads = {
		{ x = -90, z = 1, text = "SUSHI BY THE SEA!", bg = C(25, 55, 95), fg = WHITE },
		{ x = 90, z = 1, text = "SURF'S UP! GRAB A BURGER", bg = SUNNY, fg = C(30, 80, 180) },
		{ x = -90, z = -1, text = "SMOOTHIE SPLASH: 2 FOR 1", bg = LIME, fg = C(20, 70, 30) },
		{ x = 90, z = -1, text = "TACOS ON THE BEACH!", bg = SEA_BLUE, fg = SUNNY },
	}
	for i, ad in ads do
		local cf = CF(ad.x, 15.5, ad.z * 88.4) * (if ad.z > 0 then CF() else ry(180))
		sign(f, "Billboard" .. i, V(34, 7, 0.5), cf, ad.bg, ad.text, ad.fg, BLACK, WHITE, FONT)
		for _, u in { -14, 14 } do
			deco(f, "BillboardStilt", V(0.6, 12.8, 0.6), cf * CF(u, -6.4, 0.5), DRIFTWOOD, M.Wood)
		end
	end
end

-- Outside the walls: beach, ocean, piers, boats, islands, lighthouse ----------

local function buildOcean(root: Instance, m: { [string]: any })
	local f = newFolder(root, "Ocean")
	local L2, W2 = m.fieldLength / 2, m.fieldWidth / 2
	-- Outer beach (14 studs of sand past the walls) sloping into the sea.
	local beachW = 14
	deco(f, "OuterBeach", V(m.fieldLength + 2 * beachW, 1, beachW), CF(0, -0.5, W2 + beachW / 2), SAND, M.Sand)
	deco(f, "OuterBeach", V(m.fieldLength + 2 * beachW, 1, beachW), CF(0, -0.5, -W2 - beachW / 2), SAND, M.Sand)
	deco(f, "OuterBeach", V(beachW, 1, m.fieldWidth), CF(L2 + beachW / 2, -0.5, 0), SAND, M.Sand)
	deco(f, "OuterBeach", V(beachW, 1, m.fieldWidth), CF(-L2 - beachW / 2, -0.5, 0), SAND, M.Sand)
	local slopeL, slopeH = 10, 1.6
	local zOut, xOut = W2 + beachW, L2 + beachW
	wedge(f, "BeachSlope", V(2 * xOut + 2 * slopeL, slopeH, slopeL), CF(0, -slopeH / 2, zOut + slopeL / 2) * ry(180), WET_SAND, M.Sand)
	wedge(f, "BeachSlope", V(2 * xOut + 2 * slopeL, slopeH, slopeL), CF(0, -slopeH / 2, -zOut - slopeL / 2), WET_SAND, M.Sand)
	wedge(f, "BeachSlope", V(2 * zOut, slopeH, slopeL), CF(xOut + slopeL / 2, -slopeH / 2, 0) * ry(-90), WET_SAND, M.Sand)
	wedge(f, "BeachSlope", V(2 * zOut, slopeH, slopeL), CF(-xOut - slopeL / 2, -slopeH / 2, 0) * ry(90), WET_SAND, M.Sand)
	-- Sea: shallow sand shelf, deep floor, translucent surface.
	flat(f, "Shallows", V(2 * xOut + 120, 0.2, 2 * zOut + 120), CF(0, -2.2, 0), C(110, 205, 190), M.Sand)
	flat(f, "DeepSea", V(1300, 0.2, 1080), CF(0, -7, 0), C(15, 75, 135), M.Sand)
	local sea = flat(f, "Ocean", V(1300, 0.3, 1080), CF(0, -0.75, 0), OCEAN, M.Glass)
	sea.Transparency = 0.35
	sea.Reflectance = 0.2
	-- Surf lines along each shore.
	local foamZ = zOut + slopeL * (0.6 / slopeH)
	local foamX = xOut + slopeL * (0.6 / slopeH)
	for i, off in { 0, 2.4, 5.5 } do
		local t = 0.15 + (i - 1) * 0.2
		for _, zs in { -1, 1 } do
			flat(f, "SurfFoam", V(2 * foamX + 10, 0.05, 1.4 - (i - 1) * 0.35), CF(0, -0.58, zs * (foamZ + off)), WHITE).Transparency = t
		end
		for _, xs in { -1, 1 } do
			flat(f, "SurfFoam", V(1.4 - (i - 1) * 0.35, 0.05, 2 * foamZ + 10), CF(xs * (foamX + off), -0.58, 0), WHITE).Transparency = t
		end
	end
	-- Whitecaps scattered over open water.
	for _ = 1, 20 do
		local x, z
		repeat
			x, z = rrange(-560, 560), rrange(-470, 470)
		until math.abs(x) > xOut + 30 or math.abs(z) > zOut + 30
		local cap = flat(f, "Whitecap", V(rrange(5, 12), 0.05, rrange(0.6, 1.2)), CF(x, -0.57, z) * ry(rrange(-25, 25)), WHITE)
		cap.Transparency = 0.35
	end
	-- Buoys.
	for i, p in { V(-140, 0, 140), V(120, 0, 135), V(260, 0, 40), V(-260, 0, -30), V(-110, 0, -145), V(90, 0, -150) } do
		buoy(f, p + V(0, -0.8, 0), if i % 2 == 0 then C(230, 50, 40) else C(40, 170, 80))
	end

	-- Piers off the north and south beaches.
	local piers = {
		{ x = 40, zs = 1, sign = "PIZZA ON THE PIER", bg = C(220, 40, 40), fg = C(255, 230, 80) },
		{ x = -40, zs = -1, sign = "FRESH FISH TACOS", bg = SEA_BLUE, fg = SUNNY },
	}
	for _, pr in piers do
		local pf = newFolder(f, "Pier")
		local zs = pr.zs
		local z0, len = W2 + 6, 82
		local function P(x: number, y: number, z: number): CFrame
			return CF(pr.x + x, y, zs * (z0 + z)) * (if zs > 0 then CF() else ry(180))
		end
		deco(pf, "PierDeck", V(8, 0.5, len), P(0, 1.2, len / 2), DECK, M.WoodPlanks)
		for z = 4, len, 20 do
			for _, sx in { -1, 1 } do
				vcyl(pf, "PierPiling", 4.5, 0.9, P(sx * 3.6, -0.3, z), DRIFTWOOD, M.Wood)
			end
		end
		for _, sx in { -1, 1 } do
			deco(pf, "PierRail", V(0.25, 0.25, len), P(sx * 3.8, 3.6, len / 2), WHITE, M.Wood)
		end
		for _, z in { 16, 46, 76 } do
			deco(pf, "PierLampPost", V(0.35, 6, 0.35), P(3.6, 4.4, z), C(40, 70, 90), M.Metal)
			local lamp = neon(pf, "PierLamp", V(0.9, 0.9, 0.9), P(3.6, 7.6, z), C(255, 232, 175))
			light(lamp, C(255, 210, 150), 18, 1)
		end
		-- Snack shack at the end with the billboard facing the arena.
		deco(pf, "PierShack", V(7, 5, 6), P(0, 3.9, len - 4), C(250, 245, 235), M.WoodPlanks)
		deco(pf, "PierShackRoof", V(8, 0.5, 7), P(0, 6.6, len - 4), CORAL)
		local bcf = P(0, 12, len - 2)
		sign(pf, "PierBillboard", V(22, 5, 0.4), bcf, pr.bg, pr.sign, pr.fg, BLACK, WHITE, FONT, true)
		for _, u in { -8, 8 } do
			deco(pf, "PierBillboardPost", V(0.5, 6, 0.5), bcf * CF(u, -4.2, 0.3), DRIFTWOOD, M.Wood)
		end
		-- Moored boats, gulls on the pilings.
		rowboat(pf, P(7, -0.65, 26) * ry(180), WHITE, CORAL, 1.3)
		sailboat(pf, P(-10, -0.9, 62), WHITE, TURQ, 0.9)
		seagull(pf, P(-3.6, 1.95, 44) * ry(130))
	end

	-- Sailboats and a yacht out at sea.
	sailboat(f, CF(-160, -0.9, 250) * ry(70), WHITE, CORAL, 1.4)
	sailboat(f, CF(230, -0.9, -250) * ry(-110), C(30, 60, 120), WHITE, 1.6)
	sailboat(f, CF(390, -0.9, 70) * ry(10), WHITE, SUNNY, 1.3)
	sailboat(f, CF(-400, -0.9, -60) * ry(160), C(255, 120, 100), WHITE, 1.2)
	yacht(f, CF(60, -0.9, -240) * ry(100))
	-- Jumping dolphins.
	for _, d in { { -60, 200, 30 }, { 320, -150, -60 } } do
		local dc = CF(d[1], 2.5, d[2]) * ry(d[3])
		deco(f, "Dolphin", V(1.8, 1.8, 6), dc * rx(30), C(120, 140, 170))
		deco(f, "DolphinNose", V(0.8, 0.8, 2), dc * rx(30) * CF(0, -0.3, -3.6), C(120, 140, 170))
		deco(f, "DolphinBelly", V(1.6, 0.4, 5), dc * rx(30) * CF(0, -0.8, 0), C(220, 225, 235))
		triangle(f, "DolphinFin", 0.8, 1.2, 0.3, dc * rx(30) * CF(0, 1.4, 0.6) * ry(90), C(120, 140, 170))
		triangle(f, "DolphinTail", 1.4, 1.2, 0.3, dc * rx(30) * CF(0, 0, 3.6) * rx(-90), C(120, 140, 170))
		cyl(f, "DolphinSplash", V(0.06, 6, 6), CF(d[1], -0.55, d[2]) * ry(d[3]) * CF(0, 0, 4) * UP, WHITE).Transparency = 0.3
	end

	-- Islands on the horizon.
	for _, isl in { { 280, 240, 60 }, { -320, -220, 44 }, { 140, -330, 24 } } do
		local ix, iz, d = isl[1], isl[2], isl[3]
		local fI = newFolder(f, "Island")
		vcyl(fI, "IslandShelf", 0.3, d + 24, CF(ix, -1.4, iz), C(120, 215, 200), M.Sand)
		vcyl(fI, "IslandBeach", 1.2, d, CF(ix, -0.4, iz), SAND, M.Sand)
		vcyl(fI, "IslandHill", 1.6, d * 0.65, CF(ix, 0.6, iz), C(90, 170, 80), M.Grass)
		ball(fI, "IslandRock", d * 0.18, CF(ix + d * 0.3, 0, iz - d * 0.25), ROCK, M.Rock)
		local count = if d > 50 then 4 elseif d > 30 then 3 else 1
		for k = 1, count do
			local a = k / count * math.pi * 2
			local r = if count == 1 then 0 else d * 0.2
			palm(fI, V(ix + math.cos(a) * r, 1.4, iz + math.sin(a) * r), 14 + k, math.deg(a), 4, true)
		end
	end

	-- Lighthouse on a rocky point off the north-west corner.
	local lh = newFolder(f, "Lighthouse")
	local lx, lz = -236, 126
	for i, r in { { 0, 0, 22 }, { 9, 6, 14 }, { -8, 7, 12 }, { 6, -9, 11 } } do
		ball(lh, "LighthouseRock", r[3], CF(lx + r[1], -4 - i * 0.3, lz + r[2]), if i % 2 == 0 then ROCK else C(150, 145, 135), M.Rock)
	end
	local base = 7
	for i = 0, 4 do
		local dd = 8 - i * 0.5
		vcyl(lh, "LighthouseTower", 6, dd, CF(lx, base + 3 + i * 6, lz), if i % 2 == 0 then WHITE else C(220, 40, 40), M.SmoothPlastic)
	end
	local topY = base + 30
	vcyl(lh, "LighthouseGallery", 0.6, 8.6, CF(lx, topY + 0.3, lz), C(40, 40, 50), M.Metal)
	vcyl(lh, "LighthouseRail", 1.2, 8.4, CF(lx, topY + 1.2, lz), C(40, 40, 50), M.Metal).Transparency = 0.6
	local lantern = cyl(lh, "LighthouseLantern", V(4, 4.4, 4.4), CF(lx, topY + 2.6, lz) * UP, C(255, 245, 200), M.Glass)
	lantern.Transparency = 0.4
	local lamp = ball(lh, "LighthouseLamp", 2.8, CF(lx, topY + 2.6, lz), C(255, 240, 160), M.Neon)
	light(lamp, C(255, 235, 170), 60, 2)
	vcyl(lh, "LighthouseRoof", 1, 5.4, CF(lx, topY + 5.1, lz), C(220, 40, 40))
	vcyl(lh, "LighthouseRoof", 1, 3.6, CF(lx, topY + 6.1, lz), C(220, 40, 40))
	vcyl(lh, "LighthouseRoof", 1, 1.8, CF(lx, topY + 7.1, lz), C(220, 40, 40))
	ball(lh, "LighthouseFinial", 0.8, CF(lx, topY + 8, lz), GOLD, M.Metal)
	deco(lh, "LighthouseDoor", V(2, 3.6, 0.3), CF(lx + 1.5, base + 1.8, lz - 3.85), C(30, 60, 120))
	for _, wy in { 14, 22 } do
		deco(lh, "LighthouseWindow", V(1.2, 1.6, 0.3), CF(lx, base + wy, lz - 3.6), C(40, 60, 90))
	end
	seagull(lh, CF(lx + 3, topY + 0.6, lz + 2) * ry(220))

	-- Gulls wheeling over the arena.
	for _, g in { { -60, 42, 30, 20 }, { 40, 38, -40, 140 }, { 130, 46, 60, 260 }, { -140, 40, -60, 80 } } do
		seagull(f, CF(g[1], g[2], g[3]) * ry(g[4]), true)
	end
end

-- Theme ------------------------------------------------------------------------

function MapWater.buildTheme(folder: Instance, m: { [string]: any })
	seed = 20261104 -- same layout every build
	buildBoundary(folder, m)
	buildGround(folder, m)
	buildBoardwalks(folder, m)
	buildLagoon(folder)
	buildBridge(folder)
	buildShops(folder)
	buildBeach(folder)
	buildPlazas(folder)
	buildSignage(folder)
	buildOcean(folder, m)
end

-- Lighting ---------------------------------------------------------------------
-- Only the properties MapBuildings.cityLighting resets: bright tropical
-- midday, a touch warmer and more saturated than the City but kept near its
-- values (the City's first pass at Brightness 2.5 washed whites out).
function MapWater.lighting()
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 13.2
	Lighting.Brightness = 2.1
	Lighting.Ambient = C(72, 74, 80)
	Lighting.OutdoorAmbient = C(126, 132, 142)
	Lighting.ColorShift_Top = C(55, 42, 20)
	Lighting.ExposureCompensation = -0.12
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.8

	local function effect(className: string, name: string): any
		local e = Lighting:FindFirstChild(name)
		if e and e.ClassName ~= className then
			e:Destroy()
			e = nil
		end
		if not e then
			e = Instance.new(className :: any)
			e.Name = name
			e.Parent = Lighting
		end
		return e
	end
	local atm = effect("Atmosphere", "Atmosphere")
	atm.Density = 0.22
	atm.Offset = 0.1
	atm.Color = C(190, 225, 245)
	atm.Decay = C(255, 225, 185)
	atm.Glare = 0.25
	atm.Haze = 0.8
	local bloom = effect("BloomEffect", "Bloom")
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.6
	local cc = effect("ColorCorrectionEffect", "ColorCorrection")
	cc.Saturation = 0.26
	cc.Contrast = 0.07
	cc.Brightness = 0
	cc.TintColor = C(255, 251, 240)
	local rays = effect("SunRaysEffect", "SunRays")
	rays.Intensity = 0.1
	rays.Spread = 0.7
end

return MapWater
