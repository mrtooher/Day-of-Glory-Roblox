--!strict
-- Cook — GREASE SPILL: drops a trap that slows enemy raiders who cross it.
return {
	id = "GreaseSpill",
	activate = function(ctx: any, config: any): (boolean, string?)
		if ctx.activeTrapCount() >= config.maxActivePerCook then
			return false, "too many traps"
		end
		local myTeam = ctx.user.team
		ctx.placeTrap({
			kind = "GreaseSpill",
			radius = config.radius,
			lifetimeSeconds = config.lifetimeSeconds,
			onEnter = function(target)
				if target.team ~= myTeam then
					ctx.applyStatus(target, "slow", config.slowSeconds, config.speedMultiplier)
				end
			end,
		})
		return true, nil
	end,
}
