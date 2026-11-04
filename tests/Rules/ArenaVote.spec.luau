local ArenaVote = require("../../src/shared/Rules/ArenaVote")
local Config = require("../../src/shared/Config")

local IDS = { "City", "Water" }
local function first(_n: number): number
	return 1
end
local function last(n: number): number
	return n
end

return function(t)
	t.test("config lists City and Water, default City", function()
		t.eq(#Config.Arenas, 2)
		t.eq(Config.Arenas[1].id, "City")
		t.eq(Config.Arenas[2].id, "Water")
		t.eq(Config.DefaultArena, "City")
		for _, a in Config.Arenas do
			t.truthy(type(a.displayName) == "string" and #a.displayName > 0, a.id .. " displayName")
		end
	end)

	t.test("counts ignore unknown arena ids", function()
		local c = ArenaVote.counts({ a = "City", b = "Water", c = "Water", d = "Moon" }, IDS)
		t.eq(c.City, 1)
		t.eq(c.Water, 2)
		t.eq(c.Moon, nil)
	end)

	t.test("most votes wins", function()
		t.eq(ArenaVote.winner({ a = "Water", b = "Water", c = "City" }, IDS, "City", first), "Water")
		t.eq(ArenaVote.winner({ a = "City" }, IDS, "Water", last), "City")
	end)

	t.test("solo player: their pick wins", function()
		t.eq(ArenaVote.winner({ ["1"] = "Water" }, IDS, "City", first), "Water")
	end)

	t.test("tie is broken by the random pick among the tied arenas", function()
		local votes = { a = "City", b = "Water" }
		t.eq(ArenaVote.winner(votes, IDS, "City", first), "City")
		t.eq(ArenaVote.winner(votes, IDS, "City", last), "Water")
	end)

	t.test("tie pick only chooses among the top arenas", function()
		local seen: { number } = {}
		local function spy(n: number): number
			table.insert(seen, n)
			return n
		end
		-- 3 arenas, only two tied at the top
		t.eq(ArenaVote.winner({ a = "A", b = "B", c = "A", d = "B", e = "C" }, { "A", "B", "C" }, "C", spy), "B")
		t.eq(seen[1], 2, "pick called with the number of tied arenas")
	end)

	t.test("no votes keeps the current arena", function()
		t.eq(ArenaVote.winner({}, IDS, "Water", first), "Water")
		t.eq(ArenaVote.winner({ a = "Moon" }, IDS, "City", last), "City")
	end)

	t.test("votes are only taken before the match", function()
		t.truthy(ArenaVote.canVote("Waiting"))
		t.truthy(ArenaVote.canVote("Intermission"))
		t.falsy(ArenaVote.canVote("Playing"))
		t.falsy(ArenaVote.canVote("PostMatch"))
	end)

	t.test("isArena", function()
		t.truthy(ArenaVote.isArena("Water", IDS))
		t.falsy(ArenaVote.isArena("Moon", IDS))
		t.falsy(ArenaVote.isArena(nil, IDS))
		t.falsy(ArenaVote.isArena(5, IDS))
	end)
end
