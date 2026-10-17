--!strict
-- Registry of power definitions by id. In Roblox this folder becomes a
-- ModuleScript (init.luau) with the power modules as children.
local PowerBase = require(script.PowerBase)

local Powers = {
	PowerBase = PowerBase,
	definitions = {
		Yell = require(script.Yell),
		Fireball = require(script.Fireball),
		Vanish = require(script.Vanish),
		SlowMo = require(script.SlowMo),
		Whistle = require(script.Whistle),
		Sniff = require(script.Sniff),
		PizzaToss = require(script.PizzaToss),
		GreaseSpill = require(script.GreaseSpill),
	} :: { [string]: PowerBase.Definition },
}

return Powers
