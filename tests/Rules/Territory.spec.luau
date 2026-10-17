local Territory = require("../../src/shared/Rules/Territory")

local layout = { centerX = 0, neutralHalfWidth = 1, negativeSideTeam = "Red", positiveSideTeam = "Blue" }

return function(t)
	t.test("negative side belongs to Red", function()
		t.eq(Territory.ownerAt(-20, layout), "Red")
	end)
	t.test("positive side belongs to Blue", function()
		t.eq(Territory.ownerAt(20, layout), "Blue")
	end)
	t.test("center strip is neutral", function()
		t.eq(Territory.ownerAt(0, layout), nil)
		t.eq(Territory.ownerAt(0.99, layout), nil)
		t.eq(Territory.ownerAt(-1, layout), nil)
		t.eq(Territory.ownerAt(1.01, layout), "Blue")
	end)
	t.test("offset center line", function()
		local l = table.clone(layout)
		l.centerX = 50
		t.eq(Territory.ownerAt(20, l), "Red")
		t.eq(Territory.ownerAt(60, l), "Blue")
	end)
end
