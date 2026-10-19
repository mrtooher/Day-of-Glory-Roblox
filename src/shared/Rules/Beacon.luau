--!strict
-- "Metal detector" beacon near enemy food: the closer you are, the faster and
-- higher the ping. Silent beyond `farStuds`. Pure maths, unit tested.

local Beacon = {}

export type Config = {
	nearStuds: number, -- at or inside this distance: fastest / highest
	farStuds: number, -- beyond this: silent
	slowSeconds: number, -- gap between pings at farStuds
	fastSeconds: number, -- gap between pings at nearStuds
	lowPitch: number,
	highPitch: number,
}

-- 0 at farStuds, 1 at nearStuds (clamped).
local function closeness(d: number, c: Config): number
	return math.clamp((c.farStuds - d) / (c.farStuds - c.nearStuds), 0, 1)
end

-- Seconds between pings, or nil when out of range.
function Beacon.interval(d: number, c: Config): number?
	if d > c.farStuds then
		return nil
	end
	local k = closeness(d, c)
	return c.slowSeconds * (1 - k) + c.fastSeconds * k -- exact at both ends
end

function Beacon.pitch(d: number, c: Config): number
	local k = closeness(d, c)
	return c.lowPitch * (1 - k) + c.highPitch * k
end

return Beacon
