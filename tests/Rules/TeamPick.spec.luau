local TeamPick = require("../../src/shared/Rules/TeamPick")

local chars = { "Kelly", "Sol", "Vex", "Pim", "Cop", "Dog", "PizzaMan", "Cook" }

return function(t)
	t.test("can pick a free character", function()
		t.truthy(TeamPick.canPickCharacter({ "Kelly" }, "Kelly", 2, chars))
	end)

	t.test("max 2 of same character per team", function()
		local ok, reason = TeamPick.canPickCharacter({ "Kelly", "Kelly", "Sol" }, "Kelly", 2, chars)
		t.falsy(ok)
		t.eq(reason, "character full")
	end)

	t.test("unknown character rejected", function()
		local ok, reason = TeamPick.canPickCharacter({}, "Batman", 2, chars)
		t.falsy(ok)
		t.eq(reason, "unknown character")
	end)

	t.test("join goes to the team with fewer humans", function()
		t.eq(TeamPick.chooseTeamForJoin({ Red = 2, Blue = 1 }, { "Red", "Blue" }, 8), "Blue")
		t.eq(TeamPick.chooseTeamForJoin({ Red = 1, Blue = 1 }, { "Red", "Blue" }, 8), "Red")
	end)

	t.test("join returns nil when all teams full", function()
		t.eq(TeamPick.chooseTeamForJoin({ Red = 8, Blue = 8 }, { "Red", "Blue" }, 8), nil)
	end)

	t.test("bots fill both teams to 4 with 2 humans", function()
		local n = TeamPick.botsNeeded({ Red = 1, Blue = 1 }, { "Red", "Blue" }, 4, 8)
		t.eq(n.Red, 3)
		t.eq(n.Blue, 3)
	end)

	t.test("bots even out uneven teams", function()
		local n = TeamPick.botsNeeded({ Red = 6, Blue = 2 }, { "Red", "Blue" }, 4, 8)
		t.eq(n.Red, 0)
		t.eq(n.Blue, 4)
	end)

	t.test("no bots when teams are full", function()
		local n = TeamPick.botsNeeded({ Red = 8, Blue = 8 }, { "Red", "Blue" }, 4, 8)
		t.eq(n.Red, 0)
		t.eq(n.Blue, 0)
	end)

	t.test("bot character pick respects the limit", function()
		local roster = { "Kelly", "Kelly", "Sol", "Sol" }
		local c = TeamPick.pickBotCharacter(roster, chars, 2, 1)
		t.truthy(c ~= "Kelly" and c ~= "Sol", "got " .. tostring(c))
	end)

	t.test("bot character pick returns nil when everything is full", function()
		local roster = {}
		for _, c in chars do
			table.insert(roster, c)
			table.insert(roster, c)
		end
		t.eq(TeamPick.pickBotCharacter(roster, chars, 2, 1), nil)
	end)
end
