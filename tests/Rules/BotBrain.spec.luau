local BotBrain = require("../../src/shared/Rules/BotBrain")

local HOME, PANTRY, GUARD = "home", "pantry", "guard"

local function input(over)
	local i = {
		role = "raider",
		carrying = false,
		homeDropoff = HOME,
		enemyPantry = PANTRY,
		guardPoint = GUARD,
		intruder = nil,
		droppedTeamFood = nil,
		chaseRadius = 25,
	}
	for k, v in over or {} do
		i[k] = v
	end
	return i
end

return function(t)
	t.test("carrier always heads home", function()
		local d = BotBrain.decide(input({ carrying = true, intruder = { position = "x", distance = 1 } }))
		t.eq(d.action, "return")
		t.eq(d.target, HOME)
	end)

	t.test("raider raids by default", function()
		local d = BotBrain.decide(input())
		t.eq(d.action, "raid")
		t.eq(d.target, PANTRY)
	end)

	t.test("raider recovers team food dropped on the field", function()
		local d = BotBrain.decide(input({ droppedTeamFood = "drop" }))
		t.eq(d.action, "recover")
		t.eq(d.target, "drop")
	end)

	t.test("raider chases close intruder", function()
		local d = BotBrain.decide(input({ intruder = { position = "x", distance = 10 } }))
		t.eq(d.action, "chase")
		t.eq(d.target, "x")
	end)

	t.test("raider ignores far intruder", function()
		local d = BotBrain.decide(input({ intruder = { position = "x", distance = 60 } }))
		t.eq(d.action, "raid")
	end)

	t.test("defender chases any intruder", function()
		local d = BotBrain.decide(input({ role = "defender", intruder = { position = "x", distance = 60 } }))
		t.eq(d.action, "chase")
	end)

	t.test("defender guards when no intruder", function()
		local d = BotBrain.decide(input({ role = "defender" }))
		t.eq(d.action, "guard")
		t.eq(d.target, GUARD)
	end)

	t.test("assignRoles gives a quarter of bots defence, at least one", function()
		local roles = BotBrain.assignRoles(4, 0.25)
		local defenders = 0
		for _, r in roles do
			if r == "defender" then
				defenders += 1
			end
		end
		t.eq(#roles, 4)
		t.eq(defenders, 1)
		t.eq(#BotBrain.assignRoles(0, 0.25), 0)
		t.eq(BotBrain.assignRoles(1, 0.25)[1], "raider", "single bot raids")
	end)

	t.test("bad role errors", function()
		t.throws(function()
			BotBrain.decide(input({ role = "goalie" }))
		end)
	end)
end
