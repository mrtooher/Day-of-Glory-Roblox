--!strict
-- Decides whether a match is over: first to pointsToWin, otherwise the backup
-- clock (most points wins, equal points is a draw).

export type Result = {
	ended: boolean,
	winner: string?,
	reason: ("points" | "time")?,
}

export type Settings = {
	pointsToWin: number,
	durationSeconds: number,
}

local MatchEnd = {}

function MatchEnd.evaluate(scores: { [string]: number }, elapsedSeconds: number, settings: Settings): Result
	for teamId, points in scores do
		if points >= settings.pointsToWin then
			return { ended = true, winner = teamId, reason = "points" }
		end
	end

	if elapsedSeconds >= settings.durationSeconds then
		local best: string? = nil
		local bestPoints = -math.huge
		local tied = false
		for teamId, points in scores do
			if points > bestPoints then
				best, bestPoints, tied = teamId, points, false
			elseif points == bestPoints then
				tied = true
			end
		end
		return { ended = true, winner = if tied then nil else best, reason = "time" }
	end

	return { ended = false, winner = nil, reason = nil }
end

return MatchEnd
