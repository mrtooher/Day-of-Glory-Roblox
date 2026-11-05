--!strict
-- Golden Burger (Jim 2026-11-05): once a match, 3 minutes in, a golden burger
-- appears on the bridge. Anyone can grab it; carried to your own drop-off it
-- scores 2 points. Pure rules, no Roblox API calls (GoldenService drives it).
--
--   Waiting --tick(elapsed >= appearAfter)--> OnBridge --pickUp--> Carried --score--> Scored
--                                              ^   ^                 |  ^
--                         tick(dropped expired)|   |            drop |  | pickUp (any team)
--                                              +---+---- Dropped <---+--+

export type Status = "Waiting" | "OnBridge" | "Carried" | "Dropped" | "Scored"

export type State = {
	status: Status,
	carrier: string?,
	carrierTeam: string?,
	droppedAt: number?,
}

export type Actor = { id: string, team: string, carrying: boolean }

export type Settings = {
	appearAfterSeconds: number,
	points: number,
	droppedSeconds: number,
}

local GoldenBurger = {}

function GoldenBurger.new(): State
	return { status = "Waiting" }
end

-- `elapsed` = seconds since the match started; `now` = clock for drop timers.
function GoldenBurger.tick(g: State, elapsed: number, now: number, cfg: Settings): (State, ("Appeared" | "Returned")?)
	if g.status == "Waiting" and elapsed >= cfg.appearAfterSeconds then
		return { status = "OnBridge" }, "Appeared"
	end
	if g.status == "Dropped" and g.droppedAt and now - g.droppedAt >= cfg.droppedSeconds then
		return { status = "OnBridge" }, "Returned"
	end
	return g, nil
end

-- Grab it from the bridge or the ground. Any team; not while carrying food.
function GoldenBurger.pickUp(g: State, actor: Actor): (State, string?)
	if g.status ~= "OnBridge" and g.status ~= "Dropped" then
		return g, "not available"
	end
	if actor.carrying then
		return g, "already carrying"
	end
	return { status = "Carried", carrier = actor.id, carrierTeam = actor.team }, nil
end

function GoldenBurger.drop(g: State, now: number): State
	if g.status ~= "Carried" then
		error("GoldenBurger.drop: golden burger is " .. g.status)
	end
	return { status = "Dropped", carrierTeam = g.carrierTeam, droppedAt = now }
end

-- Carrier reached `dropoffTeam`'s drop-off. Returns the points scored, if any.
function GoldenBurger.score(g: State, dropoffTeam: string, cfg: Settings): (State, number?)
	if g.status ~= "Carried" or g.carrierTeam ~= dropoffTeam then
		return g, nil
	end
	return { status = "Scored" }, cfg.points
end

return GoldenBurger
