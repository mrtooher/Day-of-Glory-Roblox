--!strict
-- Wading (Jim 2026-11-04): knee-deep water in Water World slows whoever walks
-- through it. Pure rule, no Roblox API calls; StatusService feeds it each tick.
--
-- Water is a set of rectangles (zones) minus dry rectangles (holes: pad decks
-- with no water drawn; docks: water drawn underneath, dry on top) and dry
-- circles (islands). The water floor is the normal ground, so
-- height decides the rest: grounded with feet near the bed = wading; grounded
-- well above it (bridge, upper ramp) = dry; in the air = keep the last state,
-- so hopping through the lagoon doesn't dodge the slow.

export type Rect = { x1: number, x2: number, z1: number, z2: number }
export type Circle = { x: number, z: number, r: number }
export type Spec = {
	depth: number,
	speedMultiplier: number,
	zones: { Rect },
	holes: { Rect },
	docks: { Rect }?,
	islands: { Circle },
}

local Wading = {}

-- Feet higher than this above the water top while grounded count as dry.
Wading.DryClearance = 0.5

local function inRect(r: Rect, x: number, z: number): boolean
	return x >= r.x1 and x <= r.x2 and z >= r.z1 and z <= r.z2
end

-- True when (x, z) is over water: inside a zone, not in a hole or on an island.
function Wading.overWater(spec: Spec, x: number, z: number): boolean
	local inZone = false
	for _, r in spec.zones do
		if inRect(r, x, z) then
			inZone = true
			break
		end
	end
	if not inZone then
		return false
	end
	for _, r in spec.holes do
		if inRect(r, x, z) then
			return false
		end
	end
	local docks: { Rect } = spec.docks or {}
	for _, r in docks do
		if inRect(r, x, z) then
			return false
		end
	end
	for _, c in spec.islands do
		local dx, dz = x - c.x, z - c.z
		if dx * dx + dz * dz <= c.r * c.r then
			return false
		end
	end
	return true
end

-- Next wading state. `spec` nil means this arena has no water.
function Wading.step(spec: Spec?, prev: boolean, x: number, footY: number, z: number, grounded: boolean): boolean
	if spec == nil or not Wading.overWater(spec, x, z) then
		return false
	end
	if not grounded then
		return prev
	end
	return footY < spec.depth + Wading.DryClearance
end

-- Height of the feet from the root part's centre height, its full Y size and
-- the humanoid's HipHeight.
function Wading.footY(rootY: number, rootSizeY: number, hipHeight: number): number
	return rootY - rootSizeY / 2 - hipHeight
end

return Wading
