--!strict
-- Shared base class for the 8 character powers: owns the cooldown and the
-- "can this actor act right now" gate. Each power module is a plain
-- definition { id, activate } with no requires, so powers stay pure and run
-- under Lune tests; the server supplies a `ctx` that does the Roblox work.
--
-- activate(ctx, config) returns (true) when the power fired, or
-- (false, reason) when it did nothing — the cooldown is only spent on success.

export type ActorView = {
	id: string,
	team: string,
	carrying: boolean,
	characterId: string?,
}

export type Projectile = {
	kind: string,
	speed: number,
	range: number,
	onHit: (target: ActorView) -> (),
}

export type Trap = {
	kind: string,
	radius: number,
	lifetimeSeconds: number,
	onEnter: (target: ActorView) -> (),
}

export type Ctx = {
	user: ActorView,
	canAct: () -> boolean,
	enemiesWithin: (radius: number) -> { ActorView },
	nearestEnemy: (range: number, filter: ((ActorView) -> boolean)?) -> ActorView?,
	territoryOf: (target: ActorView) -> string?,
	knockback: (target: ActorView, speed: number) -> (),
	forceDrop: (target: ActorView) -> (),
	applyStatus: (target: ActorView, kind: string, seconds: number, multiplier: number?) -> (),
	setVanished: (target: ActorView, seconds: number) -> (),
	revealForTeam: (seconds: number) -> (),
	launchProjectile: (spec: Projectile) -> (),
	placeTrap: (spec: Trap) -> (),
	activeTrapCount: () -> number,
}

export type Definition = {
	id: string,
	activate: (ctx: Ctx, config: any) -> (boolean, string?),
}

local PowerBase = {}
PowerBase.__index = PowerBase

type Fields = {
	definition: Definition,
	config: any,
	duration: number,
	readyAt: number,
}

export type Power = typeof(setmetatable({} :: Fields, PowerBase))

function PowerBase.new(definition: Definition, config: any): Power
	local duration = config.cooldown
	if type(duration) ~= "number" or duration < 0 then
		error("PowerBase.new: " .. definition.id .. " needs a cooldown >= 0")
	end
	return setmetatable({
		definition = definition,
		config = config,
		duration = duration,
		readyAt = -math.huge,
	}, PowerBase)
end

function PowerBase.ready(self: Power, now: number): boolean
	return now >= self.readyAt
end

function PowerBase.remaining(self: Power, now: number): number
	return math.max(0, self.readyAt - now)
end

function PowerBase.resetCooldown(self: Power)
	self.readyAt = -math.huge
end

function PowerBase.tryActivate(self: Power, ctx: Ctx, now: number): (boolean, string?)
	if not self:ready(now) then
		return false, "cooldown"
	end
	if not ctx.canAct() then
		return false, "disabled"
	end
	local ok, reason = self.definition.activate(ctx, self.config)
	if ok then
		self.readyAt = now + self.duration
	end
	return ok, reason
end

return PowerBase
