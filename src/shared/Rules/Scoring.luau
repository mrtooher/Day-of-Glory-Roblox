--!strict
-- Pure scoring helpers. Scores are immutable maps of team id -> points.

export type Scores = { [string]: number }

local Scoring = {}

function Scoring.new(teamIds: { string }): Scores
	local scores: Scores = {}
	for _, id in teamIds do
		scores[id] = 0
	end
	return scores
end

-- Returns the new scores and whether `teamId` has reached `pointsToWin`.
function Scoring.award(scores: Scores, teamId: string, pointsToWin: number): (Scores, boolean)
	local current = scores[teamId]
	if current == nil then
		error("Scoring.award: unknown team " .. tostring(teamId))
	end
	local nextScores = table.clone(scores)
	nextScores[teamId] = current + 1
	return nextScores, nextScores[teamId] >= pointsToWin
end

-- Team with the most points, or nil when tied for the lead.
function Scoring.leader(scores: Scores): string?
	local best: string? = nil
	local bestPoints = -math.huge
	local tied = false
	for id, points in scores do
		if points > bestPoints then
			best, bestPoints, tied = id, points, false
		elseif points == bestPoints then
			tied = true
		end
	end
	return if tied then nil else best
end

return Scoring
