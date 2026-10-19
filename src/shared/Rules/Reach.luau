--!strict
-- Where pantry food sits and who is close enough to grab it.
-- Pure maths (no Roblox API) so it is unit tested.
--
-- The pantry is a counter (tools/arena-check enforces: size (4,3,14), centre
-- y 1.5, so its top is y 3). Food sits on the top in a row along Z.
-- Grabbing uses HORIZONTAL distance from your body to the food plus a height
-- window: walking up to the counter is enough, no jumping on it.

local Reach = {}

export type Vec = { X: number, Y: number, Z: number }

local SLOT_SPACING = 3
local SLOT_HEIGHT = 2.5 -- above the counter's centre: resting on its top

-- Offsets from the pantry centre for `count` food slots in a row along Z.
function Reach.slotOffsets(count: number): { Vec }
	local list = {}
	for i = 1, count do
		table.insert(list, { X = 0, Y = SLOT_HEIGHT, Z = (i - (count + 1) / 2) * SLOT_SPACING })
	end
	return list
end

function Reach.canGrab(body: Vec, slot: Vec, grab: { radius: number, maxHeight: number }): boolean
	local dx, dz = body.X - slot.X, body.Z - slot.Z
	if dx * dx + dz * dz > grab.radius * grab.radius then
		return false
	end
	return math.abs(body.Y - slot.Y) <= grab.maxHeight
end

return Reach
