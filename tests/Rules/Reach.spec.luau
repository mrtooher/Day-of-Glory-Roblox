local Reach = require("../../src/shared/Rules/Reach")
local Config = require("../../src/shared/Config")

-- New counter contract (tools/arena-check enforces it): RedPantry centre
-- (-180, 1.5, 0), size (4, 3, 14) -> top at y 3, front face at x -178.
local pantry = { X = -180, Y = 1.5, Z = 0 }
local ROOT_Y = 3 -- HumanoidRootPart height of a standing R15 character on the floor
local FRONT = -178 + 1 -- closest a root can stand to the counter's front face

local function add(a, b)
	return { X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }
end

return function(t)
	local slots = {}
	for _, o in Reach.slotOffsets(#Config.FoodTypes) do
		table.insert(slots, add(pantry, o))
	end

	t.test("food sits on the counter top, inside its length", function()
		for _, s in slots do
			t.truthy(s.Y > 3 and s.Y < 5, "slot height on counter top, got " .. s.Y)
			t.truthy(math.abs(s.Z) <= 7, "slot within counter length")
		end
	end)

	t.test("raider at the counter front grabs every slot from the middle", function()
		local body = { X = FRONT, Y = ROOT_Y, Z = 0 }
		for i, s in slots do
			t.truthy(Reach.canGrab(body, s, Config.FoodGrab), "slot " .. i)
		end
	end)

	t.test("raider at the end of the counter reaches the nearest slot", function()
		local body = { X = -180, Y = ROOT_Y, Z = 8 } -- beside the counter's +Z end
		t.truthy(Reach.canGrab(body, slots[#slots], Config.FoodGrab), "end slot")
	end)

	t.test("too far away: no grab", function()
		local body = { X = FRONT + 8, Y = ROOT_Y, Z = 0 }
		for i, s in slots do
			t.falsy(Reach.canGrab(body, s, Config.FoodGrab), "slot " .. i)
		end
	end)

	t.test("standing on a roof above the shop: no grab", function()
		local body = { X = -180, Y = 14, Z = 0 }
		t.falsy(Reach.canGrab(body, slots[1], Config.FoodGrab))
	end)
end
