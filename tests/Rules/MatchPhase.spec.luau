local MatchPhase = require("../../src/shared/Rules/MatchPhase")

local base = { minHumans = 2, intermissionSeconds = 15, postMatchSeconds = 8 }
local function input(now, humans, ended)
	return {
		now = now,
		humans = humans,
		matchEnded = ended or false,
		minHumans = base.minHumans,
		intermissionSeconds = base.intermissionSeconds,
		postMatchSeconds = base.postMatchSeconds,
	}
end

return function(t)
	t.test("waits until min humans", function()
		local s = MatchPhase.initial(0)
		s = MatchPhase.step(s, input(1, 1))
		t.eq(s.phase, "Waiting")
		s = MatchPhase.step(s, input(2, 2))
		t.eq(s.phase, "Intermission")
		t.eq(s.since, 2)
	end)

	t.test("intermission cancels if humans leave", function()
		local s = MatchPhase.step(MatchPhase.initial(0), input(1, 2))
		s = MatchPhase.step(s, input(5, 1))
		t.eq(s.phase, "Waiting")
	end)

	t.test("intermission -> playing after timer", function()
		local s = MatchPhase.step(MatchPhase.initial(0), input(0, 2))
		s = MatchPhase.step(s, input(14, 2))
		t.eq(s.phase, "Intermission")
		s = MatchPhase.step(s, input(15, 2))
		t.eq(s.phase, "Playing")
	end)

	t.test("playing -> postmatch on end, then back to waiting", function()
		local s = { phase = "Playing", since = 0 }
		s = MatchPhase.step(s, input(30, 2, false))
		t.eq(s.phase, "Playing")
		s = MatchPhase.step(s, input(31, 2, true))
		t.eq(s.phase, "PostMatch")
		s = MatchPhase.step(s, input(38, 2))
		t.eq(s.phase, "PostMatch")
		s = MatchPhase.step(s, input(39, 2))
		t.eq(s.phase, "Waiting")
	end)

	t.test("playing with zero humans ends match", function()
		local s = { phase = "Playing", since = 0 }
		s = MatchPhase.step(s, input(5, 0))
		t.eq(s.phase, "PostMatch")
	end)

	t.test("unknown phase errors", function()
		t.throws(function()
			MatchPhase.step({ phase = "Bogus", since = 0 } :: any, input(0, 2))
		end)
	end)
end
