--!strict
-- Pim — SLOW-MO: slows nearby enemies. Pim's super jump is passive and is
-- applied by the movement rules (Config.Powers.SlowMo.passiveJumpMultiplier).
return {
	id = "SlowMo",
	activate = function(ctx: any, config: any): (boolean, string?)
		for _, enemy in ctx.enemiesWithin(config.radius) do
			ctx.applyStatus(enemy, "slow", config.durationSeconds, config.speedMultiplier)
		end
		return true, nil
	end,
}
