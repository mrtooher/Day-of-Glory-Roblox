--!strict
-- Server-authoritative powers. Clients only send "use my power"; the server
-- checks the cooldown (PowerBase), builds a ctx from server-side positions and
-- runs the pure power module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Powers = require(ReplicatedStorage.Shared.Powers)
local PowerBase = require(ReplicatedStorage.Shared.Powers.PowerBase)
local Remotes = require(script.Parent.Remotes)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

local PowerService = {}

local MatchService: any, FoodService: any, StatusService: any, Effects: any

local powerByCharacter: { [string]: string } = {}
for _, c in Config.Characters do
	powerByCharacter[c.id] = c.power
end

function PowerService.init(services)
	MatchService = services.MatchService
	FoodService, StatusService, Effects = services.FoodService, services.StatusService, services.Effects
end

function PowerService.powerIdFor(characterId: string): string
	local id = powerByCharacter[characterId]
	assert(id, "no power for character " .. characterId)
	return id
end

-- Give the actor a fresh power instance for its current character.
function PowerService.assign(actor: Actor)
	local id = PowerService.powerIdFor(actor.characterId)
	actor.power = PowerBase.new(Powers.definitions[id], Config.Powers[id])
	actor.model:SetAttribute("PowerId", id)
	actor.model:SetAttribute("PowerReadyAt", 0)
end

local function makeCtx(actor: Actor): PowerBase.Ctx
	local function resolve(view: PowerBase.ActorView): Actor?
		return Actors.get(view.id)
	end

	return {
		user = Actors.view(actor),
		canAct = function()
			return StatusService.canAct(actor)
		end,
		enemiesWithin = function(radius)
			local list = {}
			for _, a in Effects.enemiesNear(actor, Actors.position(actor), radius) do
				table.insert(list, Actors.view(a))
			end
			return list
		end,
		nearestEnemy = function(range, filter)
			local best, bestDist = nil, math.huge
			for _, a in Effects.enemiesNear(actor, Actors.position(actor), range) do
				local v = Actors.view(a)
				local d = (Actors.position(a) - Actors.position(actor)).Magnitude
				if d < bestDist and (not filter or filter(v)) then
					best, bestDist = v, d
				end
			end
			return best
		end,
		territoryOf = function(view)
			local a = resolve(view)
			return if a then Actors.territoryOf(a) else nil
		end,
		knockback = function(view, speed: number)
			local a = resolve(view)
			if not a then
				return
			end
			local offset = Actors.position(a) - Actors.position(actor)
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dir = if flat.Magnitude > 0.01 then flat.Unit else actor.root.CFrame.LookVector
			local impulse = (dir * speed + Vector3.new(0, speed * 0.4, 0)) * a.root.AssemblyMass
			a.root:ApplyImpulse(impulse)
		end,
		forceDrop = function(view)
			local a = resolve(view)
			if a then
				FoodService.dropCarried(a)
			end
		end,
		applyStatus = function(view, kind, seconds, multiplier)
			local a = resolve(view)
			if a then
				StatusService.apply(a, kind, seconds, multiplier)
			end
		end,
		setVanished = function(view, seconds)
			local a = resolve(view)
			if a then
				StatusService.setVanished(a, seconds)
			end
		end,
		revealForTeam = function(seconds)
			StatusService.reveal(actor.team, seconds)
		end,
		launchProjectile = function(spec)
			Effects.launchProjectile(actor, spec)
		end,
		placeTrap = function(spec)
			Effects.placeTrap(actor, spec)
		end,
		activeTrapCount = function()
			return Effects.activeTraps(actor)
		end,
	}
end

-- Returns whether the power fired (and the reason when it didn't).
function PowerService.tryUse(actor: Actor): (boolean, string?)
	if not MatchService.isPlaying() then
		return false, "not playing"
	end
	if not actor.power then
		return false, "no power"
	end
	local now = Actors.now()
	local ok, reason = actor.power:tryActivate(makeCtx(actor), now)
	if ok then
		actor.model:SetAttribute("PowerReadyAt", now + actor.power:remaining(now))
		if actor.power.definition.id == "Yell" then
			Effects.flash(Actors.position(actor), Config.Powers.Yell.radius, Color3.fromRGB(255, 80, 80))
		end
	end
	return ok, reason
end

function PowerService.start()
	Remotes.event(Net.RequestPower).OnServerEvent:Connect(function(player: Player)
		local actor = Actors.fromPlayer(player)
		if actor then
			PowerService.tryUse(actor)
		end
	end)
end

return PowerService
