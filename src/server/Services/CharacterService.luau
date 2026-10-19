--!strict
-- Player characters become actors; character selection with the
-- max-2-per-team rule (a bot gives up its character if a human wants it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local TeamPick = require(ReplicatedStorage.Shared.Rules.TeamPick)
local CharacterSwitch = require(ReplicatedStorage.Shared.Rules.CharacterSwitch)
local Remotes = require(script.Parent.Remotes)
local MapService = require(script.Parent.MapService)
local Actors = require(script.Parent.Actors)
local LookService = require(script.Parent.LookService)
type Actor = Actors.Actor

local CharacterService = {}

local MatchService: any, FoodService: any, PowerService: any, BotService: any

local characterIds: { string } = {}
local displayNames: { [string]: string } = {
	Kelly = "KELLY",
	Sol = "SOL",
	Vex = "VEX",
	Pim = "PIM",
	Cop = "COP",
	Dog = "DOG",
	PizzaMan = "PIZZA MAN",
	Cook = "COOK",
}
for _, c in Config.Characters do
	table.insert(characterIds, c.id)
end

function CharacterService.init(services)
	MatchService, FoodService = services.MatchService, services.FoodService
	PowerService, BotService = services.PowerService, services.BotService
end

function CharacterService.characterIds(): { string }
	return characterIds
end

-- Character ids currently used on `team`, optionally skipping one actor.
function CharacterService.roster(team: string, except: Actor?): { string }
	local list = {}
	for _, a in Actors.onTeam(team) do
		if a ~= except then
			table.insert(list, a.characterId)
		end
	end
	return list
end

function CharacterService.defaultFor(team: string, except: Actor?): string
	local roster = CharacterService.roster(team, except)
	return TeamPick.pickBotCharacter(roster, characterIds, Config.MaxSameCharacterPerTeam, math.random(1, #characterIds))
		or characterIds[1]
end

-- Name tag above the head in team colour.
function CharacterService.decorate(actor: Actor)
	local head = actor.model:FindFirstChild("Head")
	local adornee: BasePart = if head and head:IsA("BasePart") then head else actor.root
	local old = adornee:FindFirstChild("NameTag")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = MapService.teamColor(actor.team).Color
	label.TextStrokeTransparency = 0.3
	label.Text = string.format("%s\n%s", displayNames[actor.characterId] or actor.characterId, actor.name)
	label.Parent = gui
	gui.Parent = adornee
	actor.humanoid.DisplayName = ""
end

function CharacterService.setCharacter(actor: Actor, characterId: string)
	Actors.setCharacterId(actor, characterId)
	LookService.apply(actor.model, characterId, MapService.teamColor(actor.team).Color)
	PowerService.assign(actor)
	CharacterService.decorate(actor)
	if actor.player then
		actor.player:SetAttribute("CharacterId", characterId)
	end
end

local function onCharacter(player: Player, model: Model)
	local team = MatchService.teamOfPlayer(player)
	if not team then
		return -- spectator
	end
	local humanoid = model:WaitForChild("Humanoid") :: Humanoid
	local root = model:WaitForChild("HumanoidRootPart") :: BasePart

	local wanted = player:GetAttribute("CharacterId")
	local actor: Actor = {
		id = "player" .. player.UserId,
		kind = "player",
		name = player.DisplayName,
		player = player,
		model = model,
		humanoid = humanoid,
		root = root,
		team = team,
		characterId = "",
		carrying = false,
		effects = {},
		vanishedUntil = 0,
		immuneUntil = Actors.now() + Config.TagImmunitySeconds,
		power = nil,
	}
	local characterId = CharacterService.defaultFor(team, nil)
	if type(wanted) == "string" then
		local roster = CharacterService.roster(team, Actors.fromPlayer(player))
		if TeamPick.canPickCharacter(roster, wanted, Config.MaxSameCharacterPerTeam, characterIds) then
			characterId = wanted
		end
	end
	actor.characterId = characterId
	Actors.add(actor)
	CharacterService.setCharacter(actor, characterId)

	humanoid.Died:Connect(function()
		FoodService.dropCarried(actor)
		Actors.remove(actor)
	end)
end

-- Error text for the picker; the counter makes a repeat of the same text
-- still reach the client (attributes only replicate on change).
local function selectError(player: Player, text: string)
	player:SetAttribute("SelectError", text)
	local count = player:GetAttribute("SelectErrorCount")
	player:SetAttribute("SelectErrorCount", (if type(count) == "number" then count else 0) + 1)
end

local function onRequest(player: Player, characterId: unknown)
	if type(characterId) ~= "string" then
		return
	end
	local actor = Actors.fromPlayer(player)
	if not actor then
		return
	end
	local spawnPos = MapService.kitchen(actor.team).spawn
	local here = Actors.position(actor)
	local allowed, why = CharacterSwitch.check({
		playing = MatchService.isPlaying(),
		carrying = actor.carrying,
		distanceFromSpawn = Vector3.new(here.X - spawnPos.X, 0, here.Z - spawnPos.Z).Magnitude,
		homeRadius = Config.HomeSwitchRadius,
	})
	if not allowed then
		selectError(player, CharacterSwitch.messages[why :: string] or "Can't switch right now.")
		return
	end

	local roster = CharacterService.roster(actor.team, actor)
	local ok, reason = TeamPick.canPickCharacter(roster, characterId, Config.MaxSameCharacterPerTeam, characterIds)
	if not ok and reason == "character full" then
		-- Humans beat bots: move a bot off this character if one has it.
		for _, other in Actors.onTeam(actor.team) do
			if other.kind == "bot" and other.characterId == characterId then
				local swapRoster = CharacterService.roster(actor.team, other)
				table.insert(swapRoster, characterId) -- the human is taking it
				local replacement = TeamPick.pickBotCharacter(
					swapRoster,
					characterIds,
					Config.MaxSameCharacterPerTeam,
					math.random(1, #characterIds)
				)
				if replacement then
					CharacterService.setCharacter(other, replacement)
					ok = true
				end
				break
			end
		end
	end

	if ok then
		player:SetAttribute("SelectError", "")
		CharacterService.setCharacter(actor, characterId)
	else
		selectError(player, if reason == "character full" then "Two of your team already play that character." else "Unknown character.")
	end
end

function CharacterService.start()
	local function hook(player: Player)
		MatchService.assignTeam(player)
		player.CharacterAdded:Connect(function(model)
			onCharacter(player, model)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		BotService.rebalance()
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		local actor = Actors.fromPlayer(player)
		if actor then
			FoodService.dropCarried(actor)
			Actors.remove(actor)
		end
		-- Give Players a moment to drop the leaving player before recounting.
		task.delay(1, BotService.rebalance)
	end)

	Remotes.event(Net.RequestCharacter).OnServerEvent:Connect(onRequest)
end

return CharacterService
