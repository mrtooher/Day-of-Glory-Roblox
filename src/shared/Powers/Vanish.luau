--!strict
-- Vex — VANISH: invisible and untaggable for a few seconds. Can't start while
-- carrying food; grabbing food ends it (enforced by the server's FoodService).
return {
	id = "Vanish",
	activate = function(ctx: any, config: any): (boolean, string?)
		if ctx.user.carrying then
			return false, "carrying"
		end
		ctx.setVanished(ctx.user, config.durationSeconds)
		return true, nil
	end,
}
