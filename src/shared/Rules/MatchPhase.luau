--!strict
-- Round flow: Waiting -> Intermission -> Playing -> PostMatch -> Waiting.

export type Phase = "Waiting" | "Intermission" | "Playing" | "PostMatch"

export type State = {
	phase: Phase,
	since: number,
}

export type Input = {
	now: number,
	humans: number,
	matchEnded: boolean,
	minHumans: number,
	intermissionSeconds: number,
	postMatchSeconds: number,
}

local MatchPhase = {}

function MatchPhase.initial(now: number): State
	return { phase = "Waiting", since = now }
end

local function enter(phase: Phase, now: number): State
	return { phase = phase, since = now }
end

function MatchPhase.step(state: State, input: Input): State
	local elapsed = input.now - state.since
	local phase = state.phase

	if phase == "Waiting" then
		if input.humans >= input.minHumans then
			return enter("Intermission", input.now)
		end
	elseif phase == "Intermission" then
		if input.humans < input.minHumans then
			return enter("Waiting", input.now)
		elseif elapsed >= input.intermissionSeconds then
			return enter("Playing", input.now)
		end
	elseif phase == "Playing" then
		if input.matchEnded or input.humans == 0 then
			return enter("PostMatch", input.now)
		end
	elseif phase == "PostMatch" then
		if elapsed >= input.postMatchSeconds then
			return enter("Waiting", input.now)
		end
	else
		error("MatchPhase.step: unknown phase " .. tostring(phase))
	end

	return state
end

return MatchPhase
