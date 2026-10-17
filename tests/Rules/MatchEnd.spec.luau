local MatchEnd = require("../../src/shared/Rules/MatchEnd")

local cfg = { pointsToWin = 10, durationSeconds = 600 }

return function(t)
	t.test("not ended mid-match", function()
		local r = MatchEnd.evaluate({ Red = 3, Blue = 9 }, 100, cfg)
		t.falsy(r.ended)
		t.eq(r.winner, nil)
	end)

	t.test("first to 10 wins on points", function()
		local r = MatchEnd.evaluate({ Red = 10, Blue = 9 }, 100, cfg)
		t.truthy(r.ended)
		t.eq(r.winner, "Red")
		t.eq(r.reason, "points")
	end)

	t.test("clock expiry: most points wins", function()
		local r = MatchEnd.evaluate({ Red = 2, Blue = 5 }, 600, cfg)
		t.truthy(r.ended)
		t.eq(r.winner, "Blue")
		t.eq(r.reason, "time")
	end)

	t.test("clock expiry with tie is a draw", function()
		local r = MatchEnd.evaluate({ Red = 4, Blue = 4 }, 601, cfg)
		t.truthy(r.ended)
		t.eq(r.winner, nil)
		t.eq(r.reason, "time")
	end)

	t.test("points win beats clock on same tick", function()
		local r = MatchEnd.evaluate({ Red = 10, Blue = 0 }, 700, cfg)
		t.eq(r.reason, "points")
	end)
end
