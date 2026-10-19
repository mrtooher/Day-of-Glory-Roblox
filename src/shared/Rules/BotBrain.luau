--!strict
-- Bot decision making, free of Roblox APIs. Positions are opaque values
-- (Vector3 in game, anything in tests); the bot service measures distances.

export type Role = "raider" | "defender"
export type Action = "return" | "raid" | "recover" | "chase" | "guard"

export type Input<P> = {
	role: Role,
	carrying: boolean,
	homeDropoff: P,
	enemyPantry: P,
	guardPoint: P,
	intruder: { position: P, distance: number }?, -- nearest enemy in our territory
	droppedTeamFood: P?, -- food our team dropped, waiting to be picked up
	chaseRadius: number, -- raiders only chase intruders this close
}

export type Decision<P> = {
	action: Action,
	target: P,
}

local BotBrain = {}

function BotBrain.decide<P>(input: Input<P>): Decision<P>
	if input.role ~= "raider" and input.role ~= "defender" then
		error("BotBrain.decide: bad role " .. tostring(input.role))
	end

	if input.carrying then
		return { action = "return", target = input.homeDropoff }
	end

	local intruder = input.intruder
	if input.role == "defender" then
		if intruder then
			return { action = "chase", target = intruder.position }
		end
		return { action = "guard", target = input.guardPoint }
	end

	if input.droppedTeamFood ~= nil then
		return { action = "recover", target = input.droppedTeamFood :: P }
	end
	if intruder and intruder.distance <= input.chaseRadius then
		return { action = "chase", target = intruder.position }
	end
	return { action = "raid", target = input.enemyPantry }
end

-- Long runs (raid / carry home) go through the bot's own lane (main street
-- or an alley) so the two teams' bots don't all collide head-on down the
-- middle. Returns where to walk now: a point in the lane `approach` studs
-- short of the target, or the target itself once that close in X.
function BotBrain.laneWaypoint(posX: number, targetX: number, targetZ: number, laneZ: number, approach: number): (number, number)
	local dx = targetX - posX
	if math.abs(dx) <= approach + 5 then
		return targetX, targetZ
	end
	local dir = if dx > 0 then 1 else -1
	return targetX - dir * approach, laneZ
end

-- Stuck check: a bot that should be moving but has covered less than
-- `minMove` studs since `sinceTime` for `seconds` is stuck (e.g. snagged on
-- a building corner while pathfinding still reports success).
-- Returns stuck?, and whether to restart the measuring window.
function BotBrain.stuck(moved: number, sinceTime: number, now: number, minMove: number, seconds: number): (boolean, boolean)
	if moved >= minMove then
		return false, true -- moving fine: restart the window from here
	end
	if now - sinceTime >= seconds then
		return true, true
	end
	return false, false
end

-- Roles for `count` bots: about `defenderShare` defend (at least one once there
-- are two or more bots), the rest raid.
function BotBrain.assignRoles(count: number, defenderShare: number): { Role }
	local defenders = if count >= 2 then math.max(1, math.floor(count * defenderShare)) else 0
	local roles: { Role } = {}
	for i = 1, count do
		table.insert(roles, if i <= defenders then "defender" else "raider")
	end
	return roles
end

return BotBrain
