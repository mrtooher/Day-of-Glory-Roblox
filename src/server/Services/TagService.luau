--!strict
-- Tagging: in your own territory, touching an enemy tags them. Contact is
-- measured from server-side root positions every tick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TagResolution = require(ReplicatedStorage.Shared.Rules.TagResolution)
local Remotes = require(script.Parent.Remotes)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

local TagService = {}

local MatchService: any, FoodService: any, StatusService: any

local TICK = 0.1

function TagService.init(services)
	MatchService = services.MatchService
	FoodService, StatusService = services.FoodService, services.StatusService
end

local function tagView(actor: Actor, now: number): TagResolution.Tagger
	return {
		team = actor.team,
		territory = Actors.territoryOf(actor),
		vanished = Actors.isVanished(actor, now),
		immune = Actors.isImmune(actor, now),
		disabled = not StatusService.canAct(actor),
	}
end

function TagService.tag(target: Actor, tagger: Actor)
	FoodService.dropCarried(target)
	StatusService.clear(target)
	MatchService.sendHome(target)
	Remotes.announce(string.format("%s tagged %s!", tagger.name, target.name))
end

local function step()
	if not MatchService.isPlaying() then
		return
	end
	local now = Actors.now()
	local list = Actors.all()
	local views = {}
	for i, a in list do
		views[i] = tagView(a, now)
	end

	local tagged: { [string]: boolean } = {}
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			if a.team == b.team or tagged[a.id] or tagged[b.id] then
				continue
			end
			if (Actors.position(a) - Actors.position(b)).Magnitude > Config.TagRange then
				continue
			end
			local who = TagResolution.resolveContact(views[i], views[j])
			if who == "a" then
				tagged[a.id] = true
				TagService.tag(a, b)
			elseif who == "b" then
				tagged[b.id] = true
				TagService.tag(b, a)
			end
		end
	end
end

function TagService.start()
	task.spawn(function()
		while true do
			step()
			task.wait(TICK)
		end
	end)
end

return TagService
