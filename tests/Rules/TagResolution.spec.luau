local TagResolution = require("../../src/shared/Rules/TagResolution")

local function actor(team, territory, extra)
	local a = { team = team, territory = territory, vanished = false, immune = false, disabled = false }
	for k, v in extra or {} do
		a[k] = v
	end
	return a
end

return function(t)
	t.test("defender in own territory tags raider", function()
		local ok = TagResolution.canTag(actor("Red", "Red"), actor("Blue", "Red"))
		t.truthy(ok)
	end)

	t.test("cannot tag teammate", function()
		local ok, reason = TagResolution.canTag(actor("Red", "Red"), actor("Red", "Red"))
		t.falsy(ok)
		t.eq(reason, "same team")
	end)

	t.test("cannot tag in enemy territory", function()
		local ok, reason = TagResolution.canTag(actor("Red", "Blue"), actor("Blue", "Blue"))
		t.falsy(ok)
		t.eq(reason, "not in own territory")
	end)

	t.test("cannot tag in neutral strip", function()
		local ok = TagResolution.canTag(actor("Red", nil), actor("Blue", nil))
		t.falsy(ok)
	end)

	t.test("vanished target is untaggable", function()
		local ok, reason = TagResolution.canTag(actor("Red", "Red"), actor("Blue", "Red", { vanished = true }))
		t.falsy(ok)
		t.eq(reason, "target vanished")
	end)

	t.test("immune target is untaggable", function()
		local ok, reason = TagResolution.canTag(actor("Red", "Red"), actor("Blue", "Red", { immune = true }))
		t.falsy(ok)
		t.eq(reason, "target immune")
	end)

	t.test("frozen/stunned tagger cannot tag", function()
		local ok, reason = TagResolution.canTag(actor("Red", "Red", { disabled = true }), actor("Blue", "Red"))
		t.falsy(ok)
		t.eq(reason, "tagger disabled")
	end)

	t.test("resolveContact picks the raider", function()
		local red, blue = actor("Red", "Red"), actor("Blue", "Red")
		t.eq(TagResolution.resolveContact(red, blue), "b")
		t.eq(TagResolution.resolveContact(blue, red), "a")
	end)

	t.test("resolveContact across the line tags nobody", function()
		t.eq(TagResolution.resolveContact(actor("Red", "Red"), actor("Blue", "Blue")), nil)
	end)
end
