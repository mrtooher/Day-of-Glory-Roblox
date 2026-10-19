--!strict
-- Pure audio decisions (no Roblox API calls) so they can be unit tested.

local AudioRules = {}

export type AudioConfig = {
	musicPhases: { string },
	playlist: { number },
	winMusic: number,
	sfx: { [string]: number },
	countdownBeepSeconds: number,
}

-- "rbxassetid://<id>", or nil when the id is 0 / missing (sound not set yet).
function AudioRules.assetUri(id: number?): string?
	if id == nil or id <= 0 then
		return nil
	end
	return string.format("rbxassetid://%.0f", id)
end

-- What should be playing in this phase: "playlist", "win", or "none".
function AudioRules.musicMode(phase: string, audio: AudioConfig): string
	for _, p in audio.musicPhases do
		if p == phase then
			return if #audio.playlist > 0 then "playlist" else "none"
		end
	end
	if phase == "PostMatch" and audio.winMusic > 0 then
		return "win"
	end
	return "none"
end

-- Next shuffled playlist index. Never repeats `last` when there are 2+ songs.
-- `roll` is a random integer in [1, count - 1] (or 1 when count <= 1).
function AudioRules.nextIndex(count: number, last: number?, roll: number): number
	if count <= 1 then
		return 1
	end
	if last == nil or last < 1 or last > count then
		return math.clamp(roll, 1, count)
	end
	-- Step 1..count-1 places past `last`, wrapping: never lands on `last`.
	local step = math.clamp(roll, 1, count - 1)
	return ((last - 1 + step) % count) + 1
end

-- Countdown cue when the whole-second count drops from prevLeft to left
-- during Intermission: "beep" on each of the last N seconds, else nil.
function AudioRules.countdownCue(prevLeft: number, left: number, beepSeconds: number): string?
	local prevWhole = math.ceil(prevLeft)
	local whole = math.ceil(left)
	if whole < prevWhole and whole >= 1 and whole <= beepSeconds then
		return "beep"
	end
	return nil
end

return AudioRules
