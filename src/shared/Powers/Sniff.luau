--!strict
-- Dog — SNIFF: sprint, and reveal vanished Vexes and food carriers to Dog's team.
return {
	id = "Sniff",
	activate = function(ctx: any, config: any): (boolean, string?)
		ctx.applyStatus(ctx.user, "boost", config.durationSeconds, config.speedMultiplier)
		ctx.revealForTeam(config.durationSeconds)
		return true, nil
	end,
}
