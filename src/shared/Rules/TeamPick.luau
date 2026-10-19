--!strict
-- Team assignment, bot fill and character limits.

local TeamPick = {}

local function countOf(list: { string }, value: string): number
	local n = 0
	for _, v in list do
		if v == value then
			n += 1
		end
	end
	return n
end

function TeamPick.canPickCharacter(
	teamRoster: { string },
	characterId: string,
	maxSame: number,
	validIds: { string }
): (boolean, string?)
	if not table.find(validIds, characterId) then
		return false, "unknown character"
	end
	if countOf(teamRoster, characterId) >= maxSame then
		return false, "character full"
	end
	return true, nil
end

-- Team with the fewest humans (ties go to the earlier team in teamOrder).
function TeamPick.chooseTeamForJoin(humanCounts: { [string]: number }, teamOrder: { string }, maxPerTeam: number): string?
	local best: string? = nil
	local bestCount = math.huge
	for _, team in teamOrder do
		local n = humanCounts[team] or 0
		if n < maxPerTeam and n < bestCount then
			best, bestCount = team, n
		end
	end
	return best
end

-- Bots per team so both teams have the same size: at least minPerTeam, at most maxPerTeam.
function TeamPick.botsNeeded(
	humanCounts: { [string]: number },
	teamOrder: { string },
	minPerTeam: number,
	maxPerTeam: number
): { [string]: number }
	local target = minPerTeam
	for _, team in teamOrder do
		target = math.max(target, humanCounts[team] or 0)
	end
	target = math.min(target, maxPerTeam)

	local result = {}
	for _, team in teamOrder do
		result[team] = math.max(0, target - (humanCounts[team] or 0))
	end
	return result
end

-- First character (starting at `seed`, wrapping) still under the limit, or nil.
function TeamPick.pickBotCharacter(teamRoster: { string }, characterIds: { string }, maxSame: number, seed: number): string?
	local n = #characterIds
	for i = 0, n - 1 do
		local id = characterIds[((seed - 1 + i) % n) + 1]
		if countOf(teamRoster, id) < maxSame then
			return id
		end
	end
	return nil
end

return TeamPick
