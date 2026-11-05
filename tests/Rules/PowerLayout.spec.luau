local PowerLayout = require("../../src/shared/Rules/PowerLayout")

local BTN = { x = 120, y = 60 }

local function overlaps(ax, ay, aw, ah, bx, by, bw, bh): boolean
	return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

return function(t)
	t.test("phone landscape: POWER sits centred above the jump button, no overlap", function()
		-- 70px jump button near the bottom-right of an 844x390 screen.
		local jump = { x = 844 - 95, y = 390 - 90, w = 70, h = 70 }
		local x, y = PowerLayout.aboveJump(jump, { x = 844, y = 390 }, BTN, 10)
		t.falsy(overlaps(x, y, BTN.x, BTN.y, jump.x, jump.y, jump.w, jump.h), "no overlap")
		t.near(y + BTN.y, jump.y - 10, 0.01, "10px gap above the jump button")
		t.truthy(x + BTN.x <= 844 - 8, "stays on screen (right)")
	end)

	t.test("tablet: big jump button, still above and clear", function()
		local jump = { x = 1024 - 170, y = 768 - 210, w = 120, h = 120 }
		local x, y = PowerLayout.aboveJump(jump, { x = 1024, y = 768 }, BTN, 10)
		t.falsy(overlaps(x, y, BTN.x, BTN.y, jump.x, jump.y, jump.w, jump.h))
		t.near(x + BTN.x / 2, jump.x + jump.w / 2, 0.01, "centred over the jump button")
	end)

	t.test("jump button hard against the right edge: POWER clamps on screen", function()
		local jump = { x = 400 - 72, y = 300 - 72, w = 70, h = 70 }
		local x, _ = PowerLayout.aboveJump(jump, { x = 400, y = 300 }, BTN, 10)
		t.near(x, 400 - 8 - BTN.x, 0.01)
	end)

	t.test("jump button near the top: POWER clamps on screen and never covers it", function()
		local jump = { x = 600, y = 20, w = 70, h = 70 }
		local x, y = PowerLayout.aboveJump(jump, { x = 800, y = 400 }, BTN, 10)
		t.truthy(y >= 8, "not above the screen")
		t.falsy(overlaps(x, y, BTN.x, BTN.y, jump.x, jump.y, jump.w, jump.h), "falls back to the left of the jump button")
	end)

	t.test("no jump button: nil (keep the default corner)", function()
		t.eq(PowerLayout.aboveJump(nil, { x = 800, y = 400 }, BTN, 10), nil)
	end)
end
