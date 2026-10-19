local FoodLayout = require("../../src/shared/Rules/FoodLayout")
local Config = require("../../src/shared/Config")

return function(t)
	t.test("real config: 2 at the base, 2 on roofs, every food exactly once", function()
		local slots = FoodLayout.slots(Config.FoodLayout, "Red")
		t.eq(#slots, #Config.FoodTypes)
		local base, roof, seen = 0, 0, {}
		for _, s in slots do
			seen[s.foodType] = (seen[s.foodType] or 0) + 1
			if s.kind == "base" then
				base += 1
			elseif s.kind == "roof" then
				roof += 1
			end
		end
		t.eq(base, 2)
		t.eq(roof, 2)
		for _, f in Config.FoodTypes do
			t.eq(seen[f], 1, f .. " placed once")
		end
	end)

	t.test("roof slots name their pedestal marker per team", function()
		local slots = FoodLayout.slots({ base = { "Pizza", "Taco" }, roof = { "Sushi", "Burger" } }, "Blue")
		local markers = {}
		for _, s in slots do
			if s.kind == "roof" then
				markers[s.foodType] = s.marker
			end
		end
		t.eq(markers.Sushi, "BlueRoofFood1")
		t.eq(markers.Burger, "BlueRoofFood2")
	end)

	t.test("base slots are numbered 1..n for the counter", function()
		local slots = FoodLayout.slots({ base = { "Pizza", "Taco" }, roof = { "Sushi", "Burger" } }, "Red")
		local idx = {}
		for _, s in slots do
			if s.kind == "base" then
				table.insert(idx, s.index)
			end
		end
		t.eq(#idx, 2)
		t.eq(idx[1], 1)
		t.eq(idx[2], 2)
	end)

	t.test("validate rejects a layout that drops or repeats a food", function()
		local ok1 = FoodLayout.validate({ base = { "Pizza" }, roof = { "Sushi", "Burger" } }, { "Pizza", "Burger", "Taco", "Sushi" })
		t.falsy(ok1)
		local ok2 = FoodLayout.validate({ base = { "Pizza", "Pizza" }, roof = { "Sushi", "Burger" } }, { "Pizza", "Burger", "Taco", "Sushi" })
		t.falsy(ok2)
		local ok3 = FoodLayout.validate({ base = { "Pizza", "Taco" }, roof = { "Sushi", "Burger" } }, { "Pizza", "Burger", "Taco", "Sushi" })
		t.truthy(ok3)
	end)
end
