local Wading = require("../../src/shared/Rules/Wading")
local Config = require("../../src/shared/Config")

return function(t)
	t.test("config: swim rings in the water, 8 s", function()
		local w = Config.Map.water
		t.eq(w.swimRing.seconds, 8)
		t.truthy(#w.swimRing.spots >= 2, "at least two rings")
		for i, s in w.swimRing.spots do
			t.truthy(Wading.overWater(w, s.x, s.z), "ring " .. i .. " sits over water")
		end
	end)

	t.test("rings are mirrored: same spots for both teams", function()
		local spots = Config.Map.water.swimRing.spots
		for i, s in spots do
			local found = false
			for _, o in spots do
				if math.abs(o.x + s.x) < 0.01 and math.abs(o.z - s.z) < 0.01 then
					found = true
				end
			end
			t.truthy(found, "ring " .. i .. " has a mirror across x = 0")
		end
	end)

	t.test("terrain slow: wading slows unless a swim ring is active", function()
		t.eq(Wading.terrainSlow(true, nil, 10, 0.7), 0.7)
		t.eq(Wading.terrainSlow(true, 12, 10, 0.7), nil, "ring active")
		t.eq(Wading.terrainSlow(true, 10, 10, 0.7), 0.7, "ring just ran out")
		t.eq(Wading.terrainSlow(false, nil, 10, 0.7), nil, "dry")
		t.eq(Wading.terrainSlow(false, 12, 10, 0.7), nil)
	end)
end
