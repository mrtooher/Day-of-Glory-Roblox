--!strict
-- Timed status effects (slow, boost, freeze, stun), Vex's vanish, Dog's
-- reveal, and applying the resulting walk speed / jump power to humanoids.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Movement = require(ReplicatedStorage.Shared.Rules.Movement)
local Wading = require(ReplicatedStorage.Shared.Rules.Wading)
local Remotes = require(script.Parent.Remotes)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

local StatusService = {}

local revealUntil: { [string]: number } = {}
-- Wading state per actor (Water World knee-deep water). Weak keys: actors
-- that leave are dropped with their table.
local wading: { [Actor]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local MapService: any

local TICK = 0.1

function StatusService.init(services)
	MapService = services.MapService
end

-- Water spec for the arena in play, or nil when it has no water.
local function waterSpec(): Wading.Spec?
	if MapService and MapService.currentArena() == "Water" then
		return Config.Map.water
	end
	return nil
end

-- Update one actor's wading state from where their feet are.
local function updateWading(actor: Actor)
	local root, humanoid = actor.root, actor.humanoid
	local now = false
	if root and root.Parent and humanoid then
		local pos = root.Position
		local foot = Wading.footY(pos.Y, root.Size.Y, humanoid.HipHeight)
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		now = Wading.step(waterSpec(), wading[actor] == true, pos.X, foot, pos.Z, grounded)
	end
	if now ~= (wading[actor] == true) then
		wading[actor] = now
		actor.model:SetAttribute("Wading", now)
	end
end

function StatusService.apply(actor: Actor, kind: Movement.EffectKind, seconds: number, multiplier: number?)
	table.insert(actor.effects, {
		kind = kind,
		multiplier = multiplier,
		expiresAt = Actors.now() + seconds,
	})
	StatusService.refresh(actor)
end

function StatusService.clear(actor: Actor)
	table.clear(actor.effects)
	actor.vanishedUntil = 0
	StatusService.refresh(actor)
end

function StatusService.setVanished(actor: Actor, seconds: number)
	actor.vanishedUntil = Actors.now() + seconds
	StatusService.refresh(actor)
end

function StatusService.cancelVanish(actor: Actor)
	if actor.vanishedUntil > 0 then
		actor.vanishedUntil = 0
		StatusService.refresh(actor)
	end
end

function StatusService.reveal(team: string, seconds: number)
	revealUntil[team] = Actors.now() + seconds
	Remotes.setState("RevealUntil_" .. team, revealUntil[team])
end

function StatusService.isRevealedTo(team: string, now: number): boolean
	return now < (revealUntil[team] or 0)
end

local function compute(actor: Actor, now: number)
	local jump = if actor.characterId == "Pim" then Config.Powers.SlowMo.passiveJumpMultiplier else 1
	return Movement.compute({
		baseWalkSpeed = Config.BaseWalkSpeed,
		baseJumpPower = Config.BaseJumpPower,
		carrying = actor.carrying,
		carrierMultiplier = Config.CarrierSpeedMultiplier,
		jumpMultiplier = jump,
		effects = actor.effects,
		now = now,
		terrainSlow = if wading[actor] then Config.Map.water.speedMultiplier else nil,
	})
end

function StatusService.canAct(actor: Actor): boolean
	return compute(actor, Actors.now()).canAct
end

-- Push current movement values and visibility flags onto the character.
function StatusService.refresh(actor: Actor)
	local now = Actors.now()
	actor.effects = Movement.prune(actor.effects, now)
	updateWading(actor)
	local r = compute(actor, now)
	local humanoid: Humanoid = actor.humanoid
	humanoid.UseJumpPower = true
	humanoid.WalkSpeed = r.walkSpeed
	humanoid.JumpPower = r.jumpPower

	local vanished = Actors.isVanished(actor, now)
	actor.model:SetAttribute("Vanished", vanished)
	actor.model:SetAttribute("VanishedUntil", if vanished then actor.vanishedUntil else 0)
	actor.model:SetAttribute("Disabled", not r.canAct)
	humanoid.DisplayDistanceType = if vanished
		then Enum.HumanoidDisplayDistanceType.None
		else Enum.HumanoidDisplayDistanceType.Viewer
end

function StatusService.start()
	task.spawn(function()
		while true do
			for _, actor in Actors.all() do
				StatusService.refresh(actor)
			end
			task.wait(TICK)
		end
	end)
end

return StatusService
