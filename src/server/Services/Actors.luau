--!strict
-- Registry of everyone on the field: human players and bots share one shape.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Territory = require(ReplicatedStorage.Shared.Rules.Territory)
local Movement = require(ReplicatedStorage.Shared.Rules.Movement)

export type Actor = {
	id: string,
	kind: "player" | "bot",
	name: string,
	player: Player?,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	team: string,
	characterId: string,
	carrying: boolean,
	effects: { Movement.Effect },
	vanishedUntil: number,
	immuneUntil: number,
	power: any, -- PowerBase.Power, set by PowerService
	role: string?, -- bots only
}

local Actors = {}

local byId: { [string]: Actor } = {}
local byModel: { [Model]: Actor } = {}
local nextBotId = 0

function Actors.init(_services) end

function Actors.now(): number
	return Workspace:GetServerTimeNow()
end

function Actors.newBotId(): string
	nextBotId += 1
	return "bot" .. nextBotId
end

function Actors.add(actor: Actor)
	local old = byId[actor.id]
	if old then
		byModel[old.model] = nil
	end
	byId[actor.id] = actor
	byModel[actor.model] = actor
	actor.model:SetAttribute("ActorId", actor.id)
	actor.model:SetAttribute("Team", actor.team)
	actor.model:SetAttribute("CharacterId", actor.characterId)
	actor.model:SetAttribute("Carrying", actor.carrying)
end

function Actors.remove(actor: Actor)
	if byId[actor.id] == actor then
		byId[actor.id] = nil
	end
	byModel[actor.model] = nil
end

function Actors.get(id: string): Actor?
	return byId[id]
end

function Actors.fromModel(model: Model): Actor?
	return byModel[model]
end

function Actors.fromPlayer(player: Player): Actor?
	return byId["player" .. player.UserId]
end

function Actors.all(): { Actor }
	local list = {}
	for _, a in byId do
		if a.humanoid.Health > 0 and a.root.Parent ~= nil then
			table.insert(list, a)
		end
	end
	return list
end

function Actors.onTeam(team: string): { Actor }
	local list = {}
	for _, a in byId do
		if a.team == team then
			table.insert(list, a)
		end
	end
	return list
end

function Actors.position(actor: Actor): Vector3
	return actor.root.Position
end

function Actors.territoryOf(actor: Actor): string?
	return Territory.ownerAt(actor.root.Position.X, Config.Map)
end

function Actors.setCarrying(actor: Actor, carrying: boolean)
	actor.carrying = carrying
	actor.model:SetAttribute("Carrying", carrying)
end

function Actors.setCharacterId(actor: Actor, characterId: string)
	actor.characterId = characterId
	actor.model:SetAttribute("CharacterId", characterId)
end

-- Plain view handed to the pure power modules.
function Actors.view(actor: Actor)
	return {
		id = actor.id,
		team = actor.team,
		carrying = actor.carrying,
		characterId = actor.characterId,
	}
end

function Actors.isVanished(actor: Actor, now: number): boolean
	return now < actor.vanishedUntil
end

function Actors.isImmune(actor: Actor, now: number): boolean
	return now < actor.immuneUntil
end

return Actors
