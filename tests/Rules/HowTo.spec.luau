local HowTo = require("../../src/shared/Rules/HowTo")
local Config = require("../../src/shared/Config")

return function(t)
	t.test("card shows while waiting and in the countdown, not during play", function()
		t.eq(HowTo.cardAutoVisible("Waiting"), true)
		t.eq(HowTo.cardAutoVisible("Intermission"), true)
		t.eq(HowTo.cardAutoVisible("Playing"), false)
		t.eq(HowTo.cardAutoVisible("PostMatch"), false)
	end)

	t.test("lines use the real win score and power key", function()
		local lines = HowTo.lines(Config)
		t.truthy(#lines >= 4, "at least 4 steps")
		local all = table.concat(lines, "\n")
		t.truthy(string.find(all, tostring(Config.PointsToWin), 1, true), "mentions points to win")
		t.truthy(string.find(all, Config.PowerKeys[1], 1, true), "mentions the power key")
	end)

	t.test("hint starts when a match starts", function()
		t.eq(HowTo.hintUntil("Intermission", "Playing", 100, 12, 0), 112)
	end)

	t.test("hint starts for a player who joins mid-match (no previous phase)", function()
		t.eq(HowTo.hintUntil(nil, "Playing", 100, 12, 0), 112)
	end)

	t.test("hint keeps its end time while the phase is unchanged", function()
		t.eq(HowTo.hintUntil("Playing", "Playing", 105, 12, 112), 112)
		t.eq(HowTo.hintUntil(nil, "Waiting", 100, 12, 0), 0)
	end)
end
