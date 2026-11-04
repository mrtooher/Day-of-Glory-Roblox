--!strict
-- Arena vote (Jim 2026-11-04): before each match players tap the arena they
-- want; most votes wins, a tie is broken at random among the tied arenas, no
-- votes keeps the current arena. Pure: no Roblox API calls, unit tested.

local ArenaVote = {}

-- voter key (player UserId as a string) -> arena id
export type Votes = { [string]: string }

function ArenaVote.isArena(id: any, arenaIds: { string }): boolean
	if type(id) ~= "string" then
		return false
	end
	return table.find(arenaIds, id) ~= nil
end

-- Votes are taken while players wait and during the countdown.
function ArenaVote.canVote(phase: string): boolean
	return phase == "Waiting" or phase == "Intermission"
end

-- Votes per arena (every listed arena present, unknown ids ignored).
function ArenaVote.counts(votes: Votes, arenaIds: { string }): { [string]: number }
	local c: { [string]: number } = {}
	for _, id in arenaIds do
		c[id] = 0
	end
	for _, choice in votes do
		if c[choice] ~= nil then
			c[choice] += 1
		end
	end
	return c
end

-- The arena for the next match. `pick(n)` returns a number 1..n (math.random
-- in the game) and is only called when two or more arenas tie for the most votes.
function ArenaVote.winner(votes: Votes, arenaIds: { string }, current: string, pick: (n: number) -> number): string
	local c = ArenaVote.counts(votes, arenaIds)
	local best = 0
	local top: { string } = {}
	for _, id in arenaIds do
		local n = c[id]
		if n > best then
			best = n
			top = { id }
		elseif n == best and n > 0 then
			table.insert(top, id)
		end
	end
	if best == 0 then
		return current
	end
	if #top == 1 then
		return top[1]
	end
	local i = math.clamp(pick(#top), 1, #top)
	return top[i]
end

return ArenaVote
