--!strict
-- Kelly — YELL: knock back enemies in a radius; enemy carriers drop their food.
return {
	id = "Yell",
	activate = function(ctx: any, config: any): (boolean, string?)
		for _, enemy in ctx.enemiesWithin(config.radius) do
			if enemy.carrying then
				ctx.forceDrop(enemy)
			end
			ctx.knockback(enemy, config.knockback)
		end
		return true, nil
	end,
}
