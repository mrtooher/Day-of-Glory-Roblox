--!strict
-- Pure audio decisions (no Roblox API calls) so they can be unit tested.

local AudioRules = {}

export type AudioConfig = {
	musicPhases: { string },
	music: { match: number, win: number },
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

-- Which music track (asset id, 0 = none) should be playing in this phase.
function AudioRules.musicFor(phase: string, audio: AudioConfig): number
	for _, p in audio.musicPhases do
		if p == phase then
			return audio.music.match
		end
	end
	if phase == "PostMatch" then
		return audio.music.win
	end
	return 0
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
