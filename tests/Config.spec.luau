local Config = require("../src/shared/Config")

return function(t)
	t.test("8 characters, each with a configured power", function()
		t.eq(#Config.Characters, 8)
		for _, c in Config.Characters do
			t.truthy(Config.Powers[c.power], "power config for " .. c.id)
		end
	end)

	t.test("every power has a positive cooldown and a display name", function()
		for id, p in Config.Powers do
			t.truthy(p.cooldown > 0, id .. " cooldown")
			t.truthy(type(p.displayName) == "string", id .. " displayName")
		end
	end)

	t.test("brief values", function()
		t.eq(Config.PointsToWin, 10)
		t.eq(Config.MatchDurationSeconds, 600)
		t.eq(Config.DroppedFoodSeconds, 10)
		t.eq(Config.MinPlayersPerTeam, 4)
		t.eq(Config.MaxPlayersPerTeam, 8)
		t.eq(Config.MaxSameCharacterPerTeam, 2)
		t.eq(#Config.Teams, 2)
		t.eq(#Config.FoodTypes, 4)
		t.eq(Config.Powers.Yell.radius, 4.5)
		t.eq(Config.Powers.Vanish.durationSeconds, 5)
		t.truthy(Config.Powers.Vanish.cooldown > Config.Powers.Vanish.durationSeconds, "vanish cooldown longer than vanish")
		t.eq(Config.Powers.SlowMo.durationSeconds, 3)
		t.eq(Config.Powers.SlowMo.passiveJumpMultiplier, 1.7)
	end)

	t.test("team slots fit within character limits", function()
		t.truthy(#Config.Characters * Config.MaxSameCharacterPerTeam >= Config.MaxPlayersPerTeam)
	end)
end
