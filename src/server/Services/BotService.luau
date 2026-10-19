--!strict
-- Bots fill empty team slots so a match can start with 2 humans. Decisions
-- come from the pure BotBrain; movement uses PathfindingService.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TeamPick = require(ReplicatedStorage.Shared.Rules.TeamPick)
local BotBrain = require(ReplicatedStorage.Shared.Rules.BotBrain)
local MapService = require(script.Parent.MapService)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

local BotService = {}

local MatchService: any, FoodService: any, PowerService: any, StatusService: any, CharacterService: any

local folder: Folder
local started = false
local rebalancing = false
local dirty = false

local POWER_RANGE = 10 -- bots consider using their power when an enemy is this close
local CHASE_RADIUS = 25

-- Each bot runs long trips in its own lane (main street or an alley) so the
-- teams' bots don't all collide head-on in the middle (Studio test
-- 2026-10-19: 0-0 after 5 min, bots tagging each other mid-field).
local LANES = { 0, 70, -70 } -- z of main street, north alley, south alley
local LANE_APPROACH = 45 -- leave the lane this many studs (X) before the target
local laneOf: { [string]: number } = {}

function BotService.init(services)
	MatchService = services.MatchService
	FoodService, PowerService = services.FoodService, services.PowerService
	StatusService, CharacterService = services.StatusService, services.CharacterService
end

local function botsOn(team: string): { Actor }
	local list = {}
	for _, a in Actors.onTeam(team) do
		if a.kind == "bot" then
			table.insert(list, a)
		end
	end
	return list
end

-- Simple blocky stand-in used if the avatar API call fails.
local function blockRig(color: BrickColor): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.BrickColor = color
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.CFrame = root.CFrame * CFrame.new(0, 1.75, 0)
	head.BrickColor = color
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function makeModel(team: string): Model
	local color = MapService.teamColor(team)
	-- A plain avatar (no accessories or clothing); LookService dresses it as
	-- the bot's Day of Glory character.
	local description = Instance.new("HumanoidDescription")
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			Enum.HumanoidRigType.R15,
			Enum.AssetTypeVerification.Default
		)
	end)
	if ok and model then
		return model
	end
	warn("BotService: avatar model failed, using block rig: " .. tostring(model))
	return blockRig(color)
end

local function nearest(from: Vector3, points: { Vector3 }): Vector3?
	local best, bestDist = nil, math.huge
	for _, p in points do
		local d = (p - from).Magnitude
		if d < bestDist then
			best, bestDist = p, d
		end
	end
	return best
end

local function think(bot: Actor, path: Path)
	local now = Actors.now()
	local pos = Actors.position(bot)
	local home = MapService.kitchen(bot.team)
	local enemyKitchen = MapService.kitchen(MapService.enemyOf(bot.team))
	local revealed = StatusService.isRevealedTo(bot.team, now)

	local intruder = nil
	local closestEnemy = math.huge
	for _, a in Actors.all() do
		if a.team == bot.team or (Actors.isVanished(a, now) and not revealed) then
			continue
		end
		local d = (Actors.position(a) - pos).Magnitude
		closestEnemy = math.min(closestEnemy, d)
		if Actors.territoryOf(a) == bot.team and (not intruder or d < intruder.distance) then
			intruder = { position = Actors.position(a), distance = d }
		end
	end

	local decision = BotBrain.decide({
		role = (bot.role or "raider") :: any,
		carrying = bot.carrying,
		homeDropoff = home.dropoff,
		enemyPantry = enemyKitchen.pantry,
		guardPoint = home.guard,
		intruder = intruder,
		droppedTeamFood = nearest(pos, FoodService.droppedBy(bot.team)),
		chaseRadius = CHASE_RADIUS,
	})

	if closestEnemy <= POWER_RANGE and math.random() < Config.Bots.powerUseChance then
		PowerService.tryUse(bot)
	end

	local target: Vector3 = decision.target
	if decision.action == "raid" then
		-- Walk up to the pantry's front, not into the counter.
		local towardCenter = Vector3.new(Config.Map.centerX - target.X, 0, 0)
		if towardCenter.Magnitude > 0 then
			target += towardCenter.Unit * 3
		end
	end
	if decision.action == "raid" or decision.action == "return" then
		local laneZ = laneOf[bot.id] or 0
		local x, z = BotBrain.laneWaypoint(pos.X, target.X, target.Z, laneZ, LANE_APPROACH)
		target = Vector3.new(x, target.Y, z)
	end

	local ok = pcall(function()
		path:ComputeAsync(pos, target)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		-- Aim a few waypoints ahead so the bot keeps moving between re-plans.
		local pick = waypoints[#waypoints]
		for i = 2, #waypoints do
			if (waypoints[i].Position - pos).Magnitude >= 10 then
				pick = waypoints[i]
				break
			end
		end
		bot.humanoid:MoveTo(pick.Position)
		if pick.Action == Enum.PathWaypointAction.Jump then
			bot.humanoid.Jump = true
		end
	else
		bot.humanoid:MoveTo(target)
	end
end

local function despawn(bot: Actor)
	laneOf[bot.id] = nil
	FoodService.dropCarried(bot)
	Actors.remove(bot)
	bot.model:Destroy()
end

local function spawnBot(team: string)
	local model = makeModel(team)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local id = Actors.newBotId()
	local characterId = CharacterService.defaultFor(team, nil)
	local bot: Actor = {
		id = id,
		kind = "bot",
		name = "Bot " .. string.sub(id, 4),
		player = nil,
		model = model,
		humanoid = humanoid,
		root = root,
		team = team,
		characterId = characterId,
		carrying = false,
		effects = {},
		vanishedUntil = 0,
		immuneUntil = 0,
		power = nil,
		role = "raider",
	}
	model.Name = bot.name
	laneOf[id] = LANES[math.random(1, #LANES)]
	model:PivotTo(MapService.spawnCFrame(team))
	model.Parent = folder
	root:SetNetworkOwner(nil) -- server drives bots
	Actors.add(bot)
	CharacterService.setCharacter(bot, characterId)

	humanoid.Died:Connect(function()
		despawn(bot)
		task.delay(3, BotService.rebalance)
	end)

	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
		})
		while Actors.get(id) == bot do
			if MatchService.isPlaying() then
				think(bot, path)
			else
				humanoid:MoveTo(root.Position)
			end
			task.wait(Config.Bots.repathSeconds)
		end
	end)
end

local function assignRoles(team: string)
	local bots = botsOn(team)
	local roles = BotBrain.assignRoles(#bots, Config.Bots.defenderShare)
	for i, bot in bots do
		bot.role = roles[i]
	end
end

local function rebalanceOnce()
	local teamIds = MatchService.teamIds()
	local needed = TeamPick.botsNeeded(
		MatchService.humanCounts(),
		teamIds,
		Config.MinPlayersPerTeam,
		Config.MaxPlayersPerTeam
	)
	for _, team in teamIds do
		local bots = botsOn(team)
		local diff = needed[team] - #bots
		for _ = 1, diff do
			spawnBot(team)
		end
		for i = 1, -diff do
			despawn(bots[i])
		end
		assignRoles(team)
	end
end

-- Match bot count to the human count. Safe to call often; calls made while a
-- rebalance is running are folded into one more pass.
function BotService.rebalance()
	if not started then
		return
	end
	if rebalancing then
		dirty = true
		return
	end
	rebalancing = true
	repeat
		dirty = false
		xpcall(rebalanceOnce, function(err)
			warn("BotService.rebalance: " .. tostring(err))
		end)
	until not dirty
	rebalancing = false
end

function BotService.start()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = Workspace
	started = true
	task.spawn(BotService.rebalance)
end

return BotService
