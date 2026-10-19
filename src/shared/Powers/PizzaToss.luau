--!strict
-- Pizza Man — PIZZA TOSS: spinning pizza that slows whoever it hits.
return {
	id = "PizzaToss",
	activate = function(ctx: any, config: any): (boolean, string?)
		ctx.launchProjectile({
			kind = "PizzaToss",
			speed = config.speed,
			range = config.range,
			onHit = function(target)
				ctx.applyStatus(target, "slow", config.slowSeconds, config.speedMultiplier)
			end,
		})
		return true, nil
	end,
}
