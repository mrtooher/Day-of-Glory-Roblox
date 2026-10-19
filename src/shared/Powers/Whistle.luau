--!strict
-- Cop — STUN GUN: fires a bolt straight ahead; the first enemy it hits is
-- frozen. Works anywhere on the map.
return {
	id = "Whistle",
	activate = function(ctx: any, config: any): (boolean, string?)
		ctx.launchProjectile({
			kind = "Whistle",
			speed = config.speed,
			range = config.range,
			onHit = function(target)
				ctx.applyStatus(target, "freeze", config.freezeSeconds, nil)
			end,
		})
		return true, nil
	end,
}
