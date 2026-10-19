--!strict
-- Walk speed / jump power from base stats, carrying, and timed status effects.
-- Slows don't stack (strongest wins); boosts don't stack (strongest wins).

export type EffectKind = "slow" | "boost" | "freeze" | "stun"

export type Effect = {
	kind: EffectKind,
	multiplier: number?,
	expiresAt: number,
}

export type Params = {
	baseWalkSpeed: number,
	baseJumpPower: number,
	carrying: boolean,
	carrierMultiplier: number,
	jumpMultiplier: number,
	effects: { Effect },
	now: number,
}

export type Result = {
	walkSpeed: number,
	jumpPower: number,
	canAct: boolean,
}

local Movement = {}

function Movement.prune(effects: { Effect }, now: number): { Effect }
	local kept = {}
	for _, e in effects do
		if e.expiresAt > now then
			table.insert(kept, e)
		end
	end
	return kept
end

function Movement.compute(p: Params): Result
	local slow, boost = 1, 1
	local disabled = false

	for _, e in p.effects do
		if e.expiresAt <= p.now then
			continue
		end
		if e.kind == "slow" then
			slow = math.min(slow, e.multiplier or 1)
		elseif e.kind == "boost" then
			boost = math.max(boost, e.multiplier or 1)
		elseif e.kind == "freeze" or e.kind == "stun" then
			disabled = true
		else
			error("Movement.compute: unknown effect kind " .. tostring(e.kind))
		end
	end

	if disabled then
		return { walkSpeed = 0, jumpPower = 0, canAct = false }
	end

	local walk = p.baseWalkSpeed * slow * boost
	if p.carrying then
		walk *= p.carrierMultiplier
	end
	return {
		walkSpeed = walk,
		jumpPower = p.baseJumpPower * p.jumpMultiplier,
		canAct = true,
	}
end

return Movement
