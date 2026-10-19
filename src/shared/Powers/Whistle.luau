--!strict
-- Cop — WHISTLE: freezes the nearest enemy that is inside the Cop's own territory.
return {
	id = "Whistle",
	activate = function(ctx: any, config: any): (boolean, string?)
		local myTeam = ctx.user.team
		local target = ctx.nearestEnemy(config.range, function(enemy)
			return ctx.territoryOf(enemy) == myTeam
		end)
		if not target then
			return false, "no target"
		end
		ctx.applyStatus(target, "freeze", config.freezeSeconds, nil)
		return true, nil
	end,
}
