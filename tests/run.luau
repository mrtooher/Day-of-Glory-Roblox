--!strict
-- Test entry point: `lune run tests/run`
-- Runs every spec listed below and fails if a spec file exists on disk but is
-- not listed (so a new test can't be silently skipped).

local fs = require("@lune/fs")
local process = require("@lune/process")
local TestKit = require("./TestKit")

local specs: { [string]: any } = {
	["Rules/Scoring.spec"] = require("./Rules/Scoring.spec"),
	["Rules/MatchEnd.spec"] = require("./Rules/MatchEnd.spec"),
	["Rules/MatchPhase.spec"] = require("./Rules/MatchPhase.spec"),
	["Rules/TagResolution.spec"] = require("./Rules/TagResolution.spec"),
	["Rules/FoodState.spec"] = require("./Rules/FoodState.spec"),
	["Rules/TeamPick.spec"] = require("./Rules/TeamPick.spec"),
	["Rules/Territory.spec"] = require("./Rules/Territory.spec"),
	["Rules/Movement.spec"] = require("./Rules/Movement.spec"),
	["Powers/Powers.spec"] = require("./Powers/Powers.spec"),
	["Rules/BotBrain.spec"] = require("./Rules/BotBrain.spec"),
	["Rules/AudioRules.spec"] = require("./Rules/AudioRules.spec"),
	["Config.spec"] = require("./Config.spec"),
	["Looks.spec"] = require("./Looks.spec"),
}

local unlisted = {}
local function scan(dir: string, prefix: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path, prefix .. name .. "/")
		elseif string.match(name, "%.spec%.luau$") then
			local key = prefix .. string.gsub(name, "%.luau$", "")
			if specs[key] == nil then
				table.insert(unlisted, key)
			end
		end
	end
end
scan("tests", "")

local totalPassed, totalFailed = 0, 0
local names = {}
for name in specs do
	table.insert(names, name)
end
table.sort(names)

for _, name in names do
	local t, results = TestKit.new(name)
	specs[name](t)
	totalPassed += results.passed
	totalFailed += results.failed
	print(string.format("%-28s %3d passed, %d failed", name, results.passed, results.failed))
	for _, f in results.failures do
		print("  FAIL " .. f)
	end
end

for _, key in unlisted do
	print("UNLISTED SPEC (add to tests/run.luau): " .. key)
	totalFailed += 1
end

print(string.format("\nTOTAL: %d passed, %d failed", totalPassed, totalFailed))
if totalPassed == 0 or totalFailed > 0 then
	process.exit(1)
end
