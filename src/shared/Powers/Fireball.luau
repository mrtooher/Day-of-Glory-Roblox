--!strict
-- Sol — FIREBALL: projectile that briefly stuns the first enemy it hits.
return {
	id = "Fireball",
	activate = function(ctx: any, config: any): (boolean, string?)
		ctx.launchProjectile({
			kind = "Fireball",
			speed = config.speed,
			range = config.range,
			onHit = function(target)
				ctx.applyStatus(target, "stun", config.stunSeconds, nil)
			end,
		})
		return true, nil
	end,
}
