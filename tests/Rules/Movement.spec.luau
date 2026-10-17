local Movement = require("../../src/shared/Rules/Movement")

local function params(over)
	local p = {
		baseWalkSpeed = 16,
		baseJumpPower = 50,
		carrying = false,
		carrierMultiplier = 0.75,
		jumpMultiplier = 1,
		effects = {},
		now = 10,
	}
	for k, v in over or {} do
		p[k] = v
	end
	return p
end

return function(t)
	t.test("base values with no effects", function()
		local r = Movement.compute(params())
		t.eq(r.walkSpeed, 16)
		t.eq(r.jumpPower, 50)
		t.truthy(r.canAct)
	end)

	t.test("carrier moves slower", function()
		t.eq(Movement.compute(params({ carrying = true })).walkSpeed, 12)
	end)

	t.test("Pim passive jump multiplier", function()
		t.near(Movement.compute(params({ jumpMultiplier = 1.7 })).jumpPower, 85)
	end)

	t.test("strongest slow wins, slows don't stack", function()
		local r = Movement.compute(params({
			effects = {
				{ kind = "slow", multiplier = 0.5, expiresAt = 20 },
				{ kind = "slow", multiplier = 0.4, expiresAt = 20 },
			},
		}))
		t.near(r.walkSpeed, 6.4)
	end)

	t.test("boost and slow combine", function()
		local r = Movement.compute(params({
			effects = {
				{ kind = "boost", multiplier = 1.5, expiresAt = 20 },
				{ kind = "slow", multiplier = 0.5, expiresAt = 20 },
			},
		}))
		t.near(r.walkSpeed, 12)
	end)

	t.test("expired effects ignored", function()
		local r = Movement.compute(params({ effects = { { kind = "slow", multiplier = 0.5, expiresAt = 10 } } }))
		t.eq(r.walkSpeed, 16)
	end)

	t.test("freeze and stun stop movement and powers", function()
		for _, kind in { "freeze", "stun" } do
			local r = Movement.compute(params({ effects = { { kind = kind, expiresAt = 11 } } }))
			t.eq(r.walkSpeed, 0, kind)
			t.eq(r.jumpPower, 0, kind)
			t.falsy(r.canAct, kind)
		end
	end)

	t.test("unknown effect kind errors", function()
		t.throws(function()
			Movement.compute(params({ effects = { { kind = "teleport", expiresAt = 99 } } }))
		end)
	end)

	t.test("prune drops expired effects", function()
		local kept = Movement.prune({
			{ kind = "slow", multiplier = 0.5, expiresAt = 5 },
			{ kind = "boost", multiplier = 1.5, expiresAt = 15 },
		}, 10)
		t.eq(#kept, 1)
		t.eq(kept[1].kind, "boost")
	end)
end
