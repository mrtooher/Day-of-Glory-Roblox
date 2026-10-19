--!strict
-- Server entry point. Services are plain modules with init(services) and an
-- optional start(); init wires references, start begins loops.

local Services = script.Parent:WaitForChild("Services")

local order = {
	"Remotes",
	"Actors",
	"MapService",
	"StatusService",
	"MatchService",
	"FoodService",
	"PickupService",
	"Effects",
	"PowerService",
	"TagService",
	"CharacterService",
	"BotService",
}

local registry: { [string]: any } = {}
for _, name in order do
	registry[name] = require(Services:WaitForChild(name) :: ModuleScript) :: any
end
for _, name in order do
	registry[name].init(registry)
end
for _, name in order do
	if registry[name].start then
		registry[name].start()
	end
end
