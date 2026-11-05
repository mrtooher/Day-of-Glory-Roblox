--!strict
-- Which animation a bot plays (Jim 2026-11-04: bots' legs didn't move). The
-- avatar's own Animate LocalScript never runs on a server-owned NPC, so the
-- server plays the same animations itself. Pure: no Roblox API calls.

local BotAnim = {}

BotAnim.IdleBelow = 0.5 -- studs/s
BotAnim.RunFrom = 10 -- studs/s: faster than this runs, slower walks
-- Ground speed at which each animation plays at 1x. Set by eye; tune in a
-- playtest if feet slide.
local NATURAL: { [string]: number } = { run = 16, walk = 8 }

-- Animation name for a Humanoid state name and horizontal speed.
function BotAnim.pick(state: string, speed: number): string
	if state == "Jumping" then
		return "jump"
	elseif state == "Freefall" or state == "FallingDown" then
		return "fall"
	elseif state == "Climbing" then
		return "climb"
	elseif state == "Seated" then
		return "sit"
	elseif state == "Swimming" then
		return "swim"
	end
	if speed < BotAnim.IdleBelow then
		return "idle"
	end
	return if speed >= BotAnim.RunFrom then "run" else "walk"
end

-- Playback speed so the feet roughly match the ground speed.
function BotAnim.speedScale(anim: string, speed: number): number
	local natural = NATURAL[anim]
	if not natural then
		return 1
	end
	return math.clamp(speed / natural, 0.1, 2)
end

return BotAnim
