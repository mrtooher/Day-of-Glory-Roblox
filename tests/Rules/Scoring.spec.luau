local Scoring = require("../../src/shared/Rules/Scoring")

return function(t)
	t.test("new starts every team at 0", function()
		local s = Scoring.new({ "Red", "Blue" })
		t.eq(s.Red, 0)
		t.eq(s.Blue, 0)
	end)

	t.test("award adds one point and does not mutate input", function()
		local s = Scoring.new({ "Red", "Blue" })
		local s2, won = Scoring.award(s, "Red", 10)
		t.eq(s2.Red, 1)
		t.eq(s.Red, 0, "original unchanged")
		t.falsy(won)
	end)

	t.test("reaching pointsToWin reports win", function()
		local s = Scoring.new({ "Red", "Blue" })
		local won = false
		for _ = 1, 10 do
			s, won = Scoring.award(s, "Blue", 10)
		end
		t.eq(s.Blue, 10)
		t.truthy(won)
	end)

	t.test("award can add more than one point (golden burger)", function()
		local s = Scoring.new({ "Red", "Blue" })
		local s2, won = Scoring.award(s, "Red", 7, 2)
		t.eq(s2.Red, 2)
		t.falsy(won)
		for _ = 1, 2 do
			s2 = Scoring.award(s2, "Red", 7)
		end
		local s3, won3 = Scoring.award(s2, "Red", 7, 2)
		t.eq(s3.Red, 6)
		t.falsy(won3)
		local s4, won4 = Scoring.award(Scoring.award(s3, "Blue", 7), "Red", 7, 2)
		t.eq(s4.Red, 8, "can pass the target")
		t.truthy(won4)
	end)

	t.test("award to unknown team errors", function()
		local s = Scoring.new({ "Red", "Blue" })
		t.throws(function()
			Scoring.award(s, "Green", 10)
		end)
	end)

	t.test("leader returns nil on tie", function()
		local s = Scoring.new({ "Red", "Blue" })
		t.eq(Scoring.leader(s), nil)
		s = Scoring.award(s, "Red", 10)
		t.eq(Scoring.leader(s), "Red")
		s = Scoring.award(s, "Blue", 10)
		t.eq(Scoring.leader(s), nil)
	end)
end
