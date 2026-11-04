--!strict
-- Round flow, Teams, scoring and the match clock.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Scoring = require(ReplicatedStorage.Shared.Rules.Scoring)
local MatchEnd = require(ReplicatedStorage.Shared.Rules.MatchEnd)
local MatchPhase = require(ReplicatedStorage.Shared.Rules.MatchPhase)
local TeamPick = require(ReplicatedStorage.Shared.Rules.TeamPick)
local ArenaVote = require(ReplicatedStorage.Shared.Rules.ArenaVote)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require(script.Parent.Remotes)
local MapService = require(script.Parent.MapService)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

local MatchService = {}

local services: any

local teamIds: { string } = {}
local teamObjects: { [string]: Team } = {}
local state: MatchPhase.State
local scores: Scoring.Scores
local matchStartedAt = 0
local forcedEnd = false

-- Arena vote: one vote per player (UserId), taken in Waiting/Intermission,
-- counted at match start, then cleared.
local arenaIds: { string } = {}
local votes: ArenaVote.Votes = {}

local TICK = 0.25

function MatchService.init(s)
	services = s
	for _, t in Config.Teams do
		table.insert(teamIds, t.id)
	end
	scores = Scoring.new(teamIds)
	for _, a in Config.Arenas do
		table.insert(arenaIds, a.id)
	end
end

function MatchService.teamIds(): { string }
	return teamIds
end

function MatchService.isPlaying(): boolean
	return state ~= nil and state.phase == "Playing"
end

function MatchService.phase(): string
	return if state then state.phase else "Waiting"
end

function MatchService.teamOfPlayer(player: Player): string?
	local team = player.Team
	local id = if team then team:GetAttribute("TeamId") else nil
	if type(id) == "string" and teamObjects[id] == team then
		return id
	end
	return nil
end

local function publish()
	Remotes.setState("Phase", state.phase)
	Remotes.setState("PointsToWin", Config.PointsToWin)
	for _, id in teamIds do
		Remotes.setState("Score_" .. id, scores[id])
	end
	local endsAt = 0
	if state.phase == "Intermission" then
		endsAt = state.since + Config.IntermissionSeconds
	elseif state.phase == "Playing" then
		endsAt = matchStartedAt + Config.MatchDurationSeconds
	elseif state.phase == "PostMatch" then
		endsAt = state.since + Config.PostMatchSeconds
	end
	Remotes.setState("PhaseEndsAt", endsAt)
end

local function publishVotes()
	local counts = ArenaVote.counts(votes, arenaIds)
	for _, id in arenaIds do
		Remotes.setState("ArenaVotes_" .. id, counts[id])
	end
end

local function arenaName(id: string): string
	for _, a in Config.Arenas do
		if a.id == id then
			return a.displayName
		end
	end
	return id
end

function MatchService.voteArena(player: Player, arenaId: any)
	if not MapService.arenaVoting() or not ArenaVote.canVote(MatchService.phase()) then
		return
	end
	if not ArenaVote.isArena(arenaId, arenaIds) then
		return
	end
	votes[tostring(player.UserId)] = arenaId
	publishVotes()
end

-- Count the votes and switch the arena (before everyone is sent home).
local function applyArenaVote()
	if MapService.arenaVoting() then
		local winner = ArenaVote.winner(votes, arenaIds, MapService.currentArena(), function(n: number): number
			return math.random(n)
		end)
		MapService.setArena(winner)
	end
	votes = {}
	publishVotes()
end

-- Teleport an actor to its spawn with brief tag immunity.
function MatchService.sendHome(actor: Actor)
	actor.model:PivotTo(MapService.spawnCFrame(actor.team))
	actor.root.AssemblyLinearVelocity = Vector3.zero
	actor.immuneUntil = Actors.now() + Config.TagImmunitySeconds
end

function MatchService.awardPoint(team: string, scorer: Actor)
	if not MatchService.isPlaying() then
		return
	end
	local won
	scores, won = Scoring.award(scores, team, Config.PointsToWin)
	Remotes.announce(string.format("%s scored for %s! (%d/%d)", scorer.name, team, scores[team], Config.PointsToWin))
	if won then
		forcedEnd = true
	end
	publish()
end

local function startMatch(now: number)
	matchStartedAt = now
	forcedEnd = false
	scores = Scoring.new(teamIds)
	services.FoodService.resetAll()
	for _, actor in Actors.all() do
		services.StatusService.clear(actor)
		if actor.power then
			actor.power:resetCooldown()
			actor.model:SetAttribute("PowerReadyAt", 0)
		end
		services.FoodService.dropCarried(actor)
		MatchService.sendHome(actor)
	end
	Remotes.setState("Winner", "")
	local where = if MapService.arenaVoting() then arenaName(MapService.currentArena()) .. "! " else ""
	Remotes.announce(where .. "Raid the enemy kitchen! First to " .. Config.PointsToWin .. " wins.")
end

local function endMatch()
	local result = MatchEnd.evaluate(scores, math.huge, {
		pointsToWin = Config.PointsToWin,
		durationSeconds = Config.MatchDurationSeconds,
	})
	local winner = result.winner
	Remotes.setState("Winner", winner or "Draw")
	Remotes.announce(if winner then Config.teamName(winner) .. " wins!" else "It's a draw!")
	services.FoodService.resetAll()
end

local function humanCount(): number
	return #Players:GetPlayers()
end

local function step()
	local now = Actors.now()
	local ended = forcedEnd
	if not ended and state.phase == "Playing" then
		ended = MatchEnd.evaluate(scores, now - matchStartedAt, {
			pointsToWin = Config.PointsToWin,
			durationSeconds = Config.MatchDurationSeconds,
		}).ended
	end

	local nextState = MatchPhase.step(state, {
		now = now,
		humans = humanCount(),
		matchEnded = ended,
		minHumans = Config.MinHumansToStart,
		intermissionSeconds = Config.IntermissionSeconds,
		postMatchSeconds = Config.PostMatchSeconds,
	})

	if nextState.phase ~= state.phase then
		state = nextState
		if state.phase == "Playing" then
			applyArenaVote()
			startMatch(now)
		elseif state.phase == "PostMatch" then
			endMatch()
		elseif state.phase == "Intermission" then
			Remotes.announce(if MapService.arenaVoting()
				then "Match starting soon - vote for the arena!"
				else "Match starting soon - pick your character!")
		end
	end
	publish()
end

local function humanCounts(): { [string]: number }
	local counts = {}
	for _, id in teamIds do
		counts[id] = 0
	end
	for _, p in Players:GetPlayers() do
		local t = MatchService.teamOfPlayer(p)
		if t then
			counts[t] += 1
		end
	end
	return counts
end

MatchService.humanCounts = humanCounts

-- Put a joining player on the team with fewer humans (no-op if already on one).
function MatchService.assignTeam(player: Player)
	if MatchService.teamOfPlayer(player) then
		return
	end
	local counts = humanCounts()
	local teamId = TeamPick.chooseTeamForJoin(counts, teamIds, Config.MaxPlayersPerTeam)
	if teamId then
		player.Team = teamObjects[teamId]
		player.Neutral = false
	else
		player.Neutral = true -- server full: spectate
	end
end

function MatchService.start()
	for _, t in Config.Teams do
		local team = Instance.new("Team")
		team.Name = t.displayName -- shown in the player list
		team:SetAttribute("TeamId", t.id) -- internal id; clients read this
		team.TeamColor = BrickColor.new(t.color :: any)
		team.AutoAssignable = false
		team.Parent = Teams
		teamObjects[t.id] = team
	end

	state = MatchPhase.initial(Actors.now())
	publish()
	publishVotes()

	Remotes.event(Net.RequestArenaVote).OnServerEvent:Connect(function(player: Player, arenaId: any)
		MatchService.voteArena(player, arenaId)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		if votes[tostring(player.UserId)] ~= nil then
			votes[tostring(player.UserId)] = nil
			publishVotes()
		end
	end)

	task.spawn(function()
		while true do
			step()
			task.wait(TICK)
		end
	end)
end

return MatchService
