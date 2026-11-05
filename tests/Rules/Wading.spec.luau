local Wading = require("../../src/shared/Rules/Wading")
local Movement = require("../../src/shared/Rules/Movement")
local Config = require("../../src/shared/Config")

-- Small hand-made spec so the tests don't depend on map numbers.
local spec = {
	depth = 1.2,
	speedMultiplier = 0.7,
	zones = { { x1 = -10, x2 = 10, z1 = -10, z2 = 10 } },
	holes = { { x1 = 4, x2 = 8, z1 = 4, z2 = 8 } },
	islands = { { x = -5, z = -5, r = 2 } },
}

local function step(prev: boolean, x: number, footY: number, z: number, grounded: boolean): boolean
	return Wading.step(spec, prev, x, footY, z, grounded)
end

return function(t)
	t.test("standing on the bed inside a zone is wading", function()
		t.truthy(step(false, 0, 0, 0, true))
	end)

	t.test("outside every zone is dry", function()
		t.falsy(step(true, 20, 0, 0, true))
		t.falsy(step(true, 0, 0, 10.5, true))
	end)

	t.test("zone edge counts as water", function()
		t.truthy(step(false, 10, 0, 0, true))
	end)

	t.test("a hole (pad deck) is dry", function()
		t.falsy(step(true, 6, 0, 6, true))
	end)

	t.test("a dock is dry", function()
		local withDock = table.clone(spec)
		withDock.docks = { { x1 = -9, x2 = -7, z1 = 6, z2 = 9 } }
		t.falsy(Wading.step(withDock, true, -8, 1.3, 7, true))
		t.truthy(Wading.step(withDock, false, -6, 0, 7, true)) -- beside it: water
	end)

	t.test("an island is dry, its shore is wet", function()
		t.falsy(step(true, -5, 1.3, -5, true))
		t.falsy(step(true, -6.9, 0.45, -5, true)) -- on the island's lowest step, inside r
		t.truthy(step(false, -7.5, 0, -5, true)) -- just outside r
	end)

	t.test("grounded high above the water (bridge, ramp) is dry", function()
		t.falsy(step(true, 0, 7, 0, true))
		t.falsy(step(true, 0, 1.2 + 0.6, 0, true))
	end)

	t.test("grounded just above the bed (shallow ramp foot) is wading", function()
		t.truthy(step(false, 0, 1.2 + 0.4, 0, true))
	end)

	t.test("jumping keeps the last state while over water", function()
		t.truthy(step(true, 0, 5, 0, false)) -- hopped from the water: still wading
		t.falsy(step(false, 0, 5, 0, false)) -- jumped off the bridge: not yet wet
	end)

	t.test("jumping out of the zone ends wading", function()
		t.falsy(step(true, 30, 3, 0, false))
	end)

	t.test("footY from root height, root size and hip height", function()
		t.near(Wading.footY(5, 2, 2), 2)
	end)

	t.test("no spec means no water (City arena)", function()
		t.falsy(Wading.step(nil, true, 0, 0, 0, true))
	end)

	t.test("wading slows like any slow: strongest slow wins", function()
		local base = {
			baseWalkSpeed = 20,
			baseJumpPower = 50,
			carrying = false,
			carrierMultiplier = 0.75,
			jumpMultiplier = 1,
			effects = {},
			now = 10,
		}
		local function walk(over)
			local p = table.clone(base)
			for k, v in over do
				p[k] = v
			end
			return Movement.compute(p).walkSpeed
		end
		t.near(walk({ terrainSlow = 0.7 }), 14)
		t.near(walk({ terrainSlow = 0.7, carrying = true }), 10.5) -- carrier multiplier still applies
		t.near(walk({ terrainSlow = 0.7, effects = { { kind = "slow", multiplier = 0.5, expiresAt = 20 } } }), 10)
		t.near(walk({ terrainSlow = 0.7, effects = { { kind = "slow", multiplier = 0.9, expiresAt = 20 } } }), 14)
		t.near(walk({}), 20) -- no terrain slow = unchanged
	end)

	t.test("Config water: knee-deep, 70%, every zone well-formed", function()
		local w = Config.Map.water
		t.truthy(w, "Config.Map.water exists")
		t.near(w.depth, 1.2)
		t.near(w.speedMultiplier, 0.7)
		t.truthy(#w.zones >= 7, "bays, middle and 4 canals")
		for i, r in w.zones do
			t.truthy(r.x1 < r.x2 and r.z1 < r.z2, "zone " .. i .. " has positive size")
		end
		for i, r in w.holes do
			t.truthy(r.x1 < r.x2 and r.z1 < r.z2, "hole " .. i .. " has positive size")
		end
		t.eq(#w.docks, 4, "4 lagoon docks")
		-- Burger spawns sit in the lagoon: grabbing one means wading.
		for _, b in Config.Map.burgerSpawns do
			t.truthy(Wading.step(w, false, b.x, 0, b.z, true), "burger spawn is in water")
		end
		-- Kitchens, drop-offs and spawns stay dry.
		for _, x in { Config.Map.pantryX, Config.Map.dropoffX, Config.Map.spawnX } do
			t.falsy(Wading.step(w, true, x, 0, 0, true), "x=" .. x .. " dry")
			t.falsy(Wading.step(w, true, -x, 0, 0, true), "x=" .. -x .. " dry")
		end
	end)
end
