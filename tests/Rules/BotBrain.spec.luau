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

	t.test("laneWaypoint: far from target -> lane point short of it", function()
		-- Red raider at its base heading to Blue pantry (180, 0), using north alley z 70.
		local x, z = BotBrain.laneWaypoint(-180, 177, 0, 70, 45)
		t.eq(x, 132)
		t.eq(z, 70)
		-- Same going the other way (Blue raider to Red pantry).
		x, z = BotBrain.laneWaypoint(180, -177, 0, -70, 45)
		t.eq(x, -132)
		t.eq(z, -70)
	end)

	t.test("laneWaypoint: close in X -> straight to the target", function()
		local x, z = BotBrain.laneWaypoint(135, 177, 0, 70, 45)
		t.eq(x, 177)
		t.eq(z, 0)
		x, z = BotBrain.laneWaypoint(177, 177, 0, 70, 45)
		t.eq(x, 177)
		t.eq(z, 0)
	end)

	t.test("laneWaypoint: lane point is reached before switching (no ping-pong)", function()
		-- Standing on the lane point itself must route to the target.
		local lx, lz = BotBrain.laneWaypoint(-180, 177, 0, 0, 45)
		local x, z = BotBrain.laneWaypoint(lx, 177, 0, 0, 45)
		t.eq(x, 177)
		t.eq(z, 0)
	end)

	t.test("stuck: moving resets the window", function()
		local isStuck, restart = BotBrain.stuck(3, 0, 1, 2, 2.5)
		t.falsy(isStuck)
		t.truthy(restart)
	end)

	t.test("stuck: barely moving, not long enough yet", function()
		local isStuck, restart = BotBrain.stuck(0.5, 0, 2, 2, 2.5)
		t.falsy(isStuck)
		t.falsy(restart)
	end)

	t.test("stuck: barely moving for the full window", function()
		local isStuck, restart = BotBrain.stuck(0.5, 0, 2.5, 2, 2.5)
		t.truthy(isStuck)
		t.truthy(restart)
	end)
end
