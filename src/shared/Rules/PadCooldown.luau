--!strict
-- Per-actor, per-pad cooldown so standing on a pad doesn't re-trigger it
-- every tick. Pure state table: { [key]: readyAt }.

local PadCooldown = {}

export type State = { [string]: number }

function PadCooldown.new(): State
	return {}
end

-- True (and arms the cooldown) when `actorId` may trigger `padName` now.
function PadCooldown.tryUse(state: State, actorId: string, padName: string, now: number, cooldown: number): boolean
	local key = actorId .. "|" .. padName
	if now < (state[key] or -math.huge) then
		return false
	end
	state[key] = now + cooldown
	return true
end

-- Drop entries for an actor that left (keeps the table small).
function PadCooldown.forget(state: State, actorId: string)
	local prefix = actorId .. "|"
	for key in state do
		if string.sub(key, 1, #prefix) == prefix then
			state[key] = nil
		end
	end
end

return PadCooldown
