local Config = require("../src/shared/Config")
local Looks = require("../src/shared/Looks")

local function isHex(s: any): boolean
	return type(s) == "string" and string.match(s, "^#%x%x%x%x%x%x$") ~= nil
end

local SHAPES = { Block = true, Ball = true, Cylinder = true, Wedge = true }

return function(t)
	t.test("every character has a look", function()
		for _, c in Config.Characters do
			t.truthy(Looks[c.id], "look for " .. c.id)
		end
	end)

	t.test("no look for a character that doesn't exist", function()
		local ids = {}
		for _, c in Config.Characters do
			ids[c.id] = true
		end
		for id in Looks do
			t.truthy(ids[id], "unknown character in Looks: " .. id)
		end
	end)

	t.test("body colours are #rrggbb", function()
		for id, look in Looks do
			for _, key in { "skin", "shirt", "pants", "shoes" } do
				t.truthy(isHex((look :: any)[key]), id .. "." .. key)
			end
			t.truthy(look.sleeve == nil or isHex(look.sleeve), id .. ".sleeve")
		end
	end)

	t.test("every part is well formed", function()
		for id, look in Looks do
			t.truthy(#look.parts > 0, id .. " has parts")
			local names = {}
			for _, p in look.parts do
				local where = id .. "." .. tostring(p.name)
				t.truthy(type(p.name) == "string" and not names[p.name], where .. " unique name")
				names[p.name] = true
				t.truthy(p.attach == "head" or p.attach == "torso", where .. " attach")
				t.truthy(SHAPES[p.shape], where .. " shape")
				t.truthy(isHex(p.color), where .. " color")
				t.eq(#p.offset, 3)
				t.eq(#p.size, 3)
				for _, v in p.size do
					t.truthy(v > 0, where .. " size > 0")
				end
				if p.rotate then
					t.eq(#p.rotate, 3)
				end
			end
		end
	end)
end
