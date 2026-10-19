local Beacon = require("../../src/shared/Rules/Beacon")

local cfg = { nearStuds = 8, farStuds = 45, slowSeconds = 1.0, fastSeconds = 0.15, lowPitch = 1.0, highPitch = 1.8 }

return function(t)
	t.test("silent beyond the far range", function()
		t.eq(Beacon.interval(45.1, cfg), nil)
		t.eq(Beacon.interval(200, cfg), nil)
	end)

	t.test("slowest ping at the edge of range, fastest when close", function()
		t.eq(Beacon.interval(45, cfg), 1.0)
		t.eq(Beacon.interval(8, cfg), 0.15)
		t.eq(Beacon.interval(2, cfg), 0.15)
	end)

	t.test("gets faster as you get closer (monotonic)", function()
		local last = math.huge
		for d = 45, 8, -1 do
			local i = Beacon.interval(d, cfg) :: number
			t.truthy(i <= last, "interval at " .. d)
			last = i
		end
	end)

	t.test("pitch rises as you get closer", function()
		t.eq(Beacon.pitch(45, cfg), 1.0)
		t.eq(Beacon.pitch(8, cfg), 1.8)
		t.truthy(Beacon.pitch(20, cfg) > Beacon.pitch(30, cfg), "closer is higher")
	end)
end
