--!strict
-- When a player may change character. Between matches: always. During a
-- match: only near their own spawn and not while carrying food.

local CharacterSwitch = {}

export type Input = {
	playing: boolean,
	carrying: boolean,
	distanceFromSpawn: number,
	homeRadius: number,
}

function CharacterSwitch.check(input: Input): (boolean, string?)
	if not input.playing then
		return true, nil
	end
	if input.carrying then
		return false, "carrying"
	end
	if input.distanceFromSpawn > input.homeRadius then
		return false, "not home"
	end
	return true, nil
end

CharacterSwitch.messages = {
	carrying = "Drop off your food first.",
	["not home"] = "Go back to your base (glowing circle) to switch.",
}

return CharacterSwitch
