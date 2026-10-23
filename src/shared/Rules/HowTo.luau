--!strict
-- "How to play" content and timing (pure: no Roblox API calls, unit tested).
-- Jim 2026-10-22: two players couldn't figure out how to play.

local HowTo = {}

export type HowToConfig = {
	PointsToWin: number,
	PowerKeys: { string },
}

-- The card opens by itself while players wait and during the countdown.
function HowTo.cardAutoVisible(phase: string): boolean
	return phase == "Waiting" or phase == "Intermission"
end

-- The steps shown on the card.
function HowTo.lines(config: HowToConfig): { string }
	return {
		"1. Run to the ENEMY kitchen - follow the yellow RAID marker.",
		"2. Grab their food: on the counter, and on the rooftops (take the stairs).",
		"3. Carry it to YOUR kitchen - follow the glowing beam home.",
		string.format("4. First team to %d food wins!", config.PointsToWin),
		"5. On YOUR side, touch enemy raiders to tag them - they drop the food.",
		string.format("POWER: when the match starts, tap your power button (bottom right) or press %s.", config.PowerKeys[1]),
	}
end

-- When the short "grab enemy food" hint should stop showing.
-- A new Playing phase (match start, or first look after joining mid-match,
-- when prevPhase is nil) starts a fresh hint; otherwise keep the current end.
function HowTo.hintUntil(prevPhase: string?, phase: string, now: number, seconds: number, current: number): number
	if phase == "Playing" and prevPhase ~= "Playing" then
		return now + seconds
	end
	return current
end

return HowTo
