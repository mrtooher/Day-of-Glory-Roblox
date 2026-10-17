--!strict
-- Cooldown timer. Time is passed in so the class stays pure and testable.

local Cooldown = {}
Cooldown.__index = Cooldown

export type Cooldown = typeof(setmetatable({} :: { duration: number, readyAt: number }, Cooldown))

function Cooldown.new(duration: number): Cooldown
	if duration < 0 then
		error("Cooldown.new: duration must be >= 0")
	end
	return setmetatable({ duration = duration, readyAt = -math.huge }, Cooldown)
end

function Cooldown.ready(self: Cooldown, now: number): boolean
	return now >= self.readyAt
end

function Cooldown.remaining(self: Cooldown, now: number): number
	return math.max(0, self.readyAt - now)
end

-- Starts the cooldown. Returns false (and changes nothing) if not ready.
function Cooldown.trigger(self: Cooldown, now: number): boolean
	if not self:ready(now) then
		return false
	end
	self.readyAt = now + self.duration
	return true
end

function Cooldown.reset(self: Cooldown)
	self.readyAt = -math.huge
end

return Cooldown
