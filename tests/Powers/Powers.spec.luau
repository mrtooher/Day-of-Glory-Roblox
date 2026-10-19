local Config = require("../../src/shared/Config")
local PowerBase = require("../../src/shared/Powers/PowerBase")

local defs = {
	Yell = require("../../src/shared/Powers/Yell"),
	Fireball = require("../../src/shared/Powers/Fireball"),
	Vanish = require("../../src/shared/Powers/Vanish"),
	SlowMo = require("../../src/shared/Powers/SlowMo"),
	Whistle = require("../../src/shared/Powers/Whistle"),
	Sniff = require("../../src/shared/Powers/Sniff"),
	PizzaToss = require("../../src/shared/Powers/PizzaToss"),
	GreaseSpill = require("../../src/shared/Powers/GreaseSpill"),
}

-- Fake server context: records every effect the power asks for.
local function fakeCtx(opts)
	opts = opts or {}
	local log = {}
	local user = opts.user or { id = "u", team = "Red", carrying = false }
	local enemies = opts.enemies or {}
	local territories = opts.territories or {}
	local ctx = {
		user = user,
		canAct = function()
			return opts.canAct ~= false
		end,
		enemiesWithin = function(radius)
			table.insert(log, { "enemiesWithin", radius })
			return enemies
		end,
		nearestEnemy = function(range, filter)
			table.insert(log, { "nearestEnemy", range })
			for _, e in enemies do
				if not filter or filter(e) then
					return e
				end
			end
			return nil
		end,
		territoryOf = function(target)
			return territories[target.id]
		end,
		knockback = function(target, speed)
			table.insert(log, { "knockback", target.id, speed })
		end,
		forceDrop = function(target)
			table.insert(log, { "forceDrop", target.id })
		end,
		applyStatus = function(target, kind, seconds, mult)
			table.insert(log, { "status", target.id, kind, seconds, mult })
		end,
		setVanished = function(target, seconds)
			table.insert(log, { "vanish", target.id, seconds })
		end,
		revealForTeam = function(seconds)
			table.insert(log, { "reveal", seconds })
		end,
		launchProjectile = function(spec)
			table.insert(log, { "projectile", spec.kind, spec.speed, spec.range })
			if opts.projectileHits then
				spec.onHit(opts.projectileHits)
			end
		end,
		placeTrap = function(spec)
			table.insert(log, { "trap", spec.kind, spec.radius, spec.lifetimeSeconds })
			for _, target in opts.trapVictims or {} do
				spec.onEnter(target)
			end
		end,
		activeTrapCount = function()
			return opts.trapCount or 0
		end,
	}
	return ctx, log
end

local function find(log, name)
	local found = {}
	for _, e in log do
		if e[1] == name then
			table.insert(found, e)
		end
	end
	return found
end

local function power(id)
	return PowerBase.new(defs[id], Config.Powers[id])
end

local blue1 = { id = "b1", team = "Blue", carrying = false }
local blueCarrier = { id = "b2", team = "Blue", carrying = true }

return function(t)
	-- PowerBase (shared cooldown) --------------------------------------------
	t.test("every character's power has a module", function()
		for _, c in Config.Characters do
			t.truthy(defs[c.power], c.power)
			t.eq(defs[c.power].id, c.power)
		end
	end)

	t.test("ready at start, cooldown after use", function()
		local p = power("Yell")
		local ctx = fakeCtx()
		t.truthy(p:ready(0))
		t.truthy(p:tryActivate(ctx, 10))
		t.near(p:remaining(12), 3)
		local ok, reason = p:tryActivate(ctx, 14.9)
		t.falsy(ok)
		t.eq(reason, "cooldown")
		t.truthy(p:tryActivate(ctx, 15))
	end)

	t.test("disabled actor cannot use power and keeps cooldown", function()
		local p = power("Yell")
		local ok, reason = p:tryActivate(fakeCtx({ canAct = false }), 10)
		t.falsy(ok)
		t.eq(reason, "disabled")
		t.truthy(p:ready(10))
	end)

	t.test("failed activation does not spend cooldown", function()
		local p = power("Whistle")
		local ok, reason = p:tryActivate(fakeCtx(), 10)
		t.falsy(ok)
		t.eq(reason, "no target")
		t.truthy(p:ready(10))
	end)

	t.test("resetCooldown", function()
		local p = power("Yell")
		p:tryActivate(fakeCtx(), 10)
		p:resetCooldown()
		t.truthy(p:ready(10))
	end)

	t.test("missing cooldown config errors", function()
		t.throws(function()
			PowerBase.new(defs.Yell, { radius = 4 })
		end)
		t.throws(function()
			PowerBase.new(defs.Yell, { cooldown = -1 })
		end)
	end)

	-- Individual powers -------------------------------------------------------
	t.test("Yell knocks back everyone in radius and drops carrier food", function()
		local ctx, log = fakeCtx({ enemies = { blue1, blueCarrier } })
		t.truthy(power("Yell"):tryActivate(ctx, 0))
		t.eq(find(log, "enemiesWithin")[1][2], 4.5)
		t.eq(#find(log, "knockback"), 2)
		local drops = find(log, "forceDrop")
		t.eq(#drops, 1)
		t.eq(drops[1][2], "b2")
	end)

	t.test("Fireball launches and stuns on hit", function()
		local ctx, log = fakeCtx({ projectileHits = blue1 })
		t.truthy(power("Fireball"):tryActivate(ctx, 0))
		t.eq(find(log, "projectile")[1][2], "Fireball")
		local s = find(log, "status")[1]
		t.eq(s[2], "b1")
		t.eq(s[3], "stun")
		t.eq(s[4], Config.Powers.Fireball.stunSeconds)
	end)

	t.test("Vanish hides user for 3s", function()
		local ctx, log = fakeCtx()
		t.truthy(power("Vanish"):tryActivate(ctx, 0))
		t.eq(find(log, "vanish")[1][3], 3)
	end)

	t.test("Vanish refused while carrying food", function()
		local ctx, log = fakeCtx({ user = { id = "v", team = "Red", carrying = true } })
		local ok, reason = power("Vanish"):tryActivate(ctx, 0)
		t.falsy(ok)
		t.eq(reason, "carrying")
		t.eq(#find(log, "vanish"), 0)
	end)

	t.test("SlowMo slows enemies in radius for 3s", function()
		local ctx, log = fakeCtx({ enemies = { blue1 } })
		t.truthy(power("SlowMo"):tryActivate(ctx, 0))
		local s = find(log, "status")[1]
		t.eq(s[3], "slow")
		t.eq(s[4], 3)
		t.eq(s[5], Config.Powers.SlowMo.speedMultiplier)
	end)

	t.test("Whistle freezes nearest enemy inside Cop's territory only", function()
		local outside = { id = "out", team = "Blue", carrying = false }
		local inside = { id = "in", team = "Blue", carrying = false }
		local ctx, log = fakeCtx({
			enemies = { outside, inside },
			territories = { out = "Blue", ["in"] = "Red" },
		})
		t.truthy(power("Whistle"):tryActivate(ctx, 0))
		local s = find(log, "status")
		t.eq(#s, 1)
		t.eq(s[1][2], "in")
		t.eq(s[1][3], "freeze")
	end)

	t.test("Sniff boosts Dog and reveals for the team", function()
		local ctx, log = fakeCtx()
		t.truthy(power("Sniff"):tryActivate(ctx, 0))
		local s = find(log, "status")[1]
		t.eq(s[2], "u")
		t.eq(s[3], "boost")
		t.eq(#find(log, "reveal"), 1)
	end)

	t.test("PizzaToss slows on hit", function()
		local ctx, log = fakeCtx({ projectileHits = blue1 })
		t.truthy(power("PizzaToss"):tryActivate(ctx, 0))
		t.eq(find(log, "projectile")[1][2], "PizzaToss")
		t.eq(find(log, "status")[1][3], "slow")
	end)

	t.test("GreaseSpill slows enemies only", function()
		local mate = { id = "r2", team = "Red", carrying = false }
		local ctx, log = fakeCtx({ trapVictims = { mate, blue1 } })
		t.truthy(power("GreaseSpill"):tryActivate(ctx, 0))
		local s = find(log, "status")
		t.eq(#s, 1)
		t.eq(s[1][2], "b1")
	end)

	t.test("GreaseSpill refused at trap limit", function()
		local ctx = fakeCtx({ trapCount = Config.Powers.GreaseSpill.maxActivePerCook })
		local ok, reason = power("GreaseSpill"):tryActivate(ctx, 0)
		t.falsy(ok)
		t.eq(reason, "too many traps")
	end)
end
