local CharacterSwitch = require("../../src/shared/Rules/CharacterSwitch")
local Config = require("../../src/shared/Config")

local function input(playing, carrying, distance)
	return {
		playing = playing,
		carrying = carrying,
		distanceFromSpawn = distance,
		homeRadius = 20,
	}
end

return function(t)
	t.test("between matches: switch anywhere, even carrying", function()
		t.truthy(CharacterSwitch.check(input(false, false, 300)))
		t.truthy(CharacterSwitch.check(input(false, true, 300)))
	end)

	t.test("mid-match: allowed at home base", function()
		t.truthy(CharacterSwitch.check(input(true, false, 0)))
		t.truthy(CharacterSwitch.check(input(true, false, 20)))
	end)

	t.test("mid-match: refused away from base", function()
		local ok, why = CharacterSwitch.check(input(true, false, 20.5))
		t.falsy(ok)
		t.eq(why, "not home")
	end)

	t.test("mid-match: refused while carrying food, even at base", function()
		local ok, why = CharacterSwitch.check(input(true, true, 0))
		t.falsy(ok)
		t.eq(why, "carrying")
	end)

	t.test("every refusal has a message; radius configured", function()
		t.truthy(CharacterSwitch.messages["not home"], "not home message")
		t.truthy(CharacterSwitch.messages.carrying, "carrying message")
		t.truthy(Config.HomeSwitchRadius > 0, "radius > 0")
	end)
end
