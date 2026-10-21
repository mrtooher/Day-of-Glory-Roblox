--!strict
-- Scoreboard (points to 10), match clock, phase text and announcements.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Hud = {}

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Hud.start()
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild(Net.MatchStateFolder)
	local remotes = ReplicatedStorage:WaitForChild(Net.RemotesFolder)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local bar = Instance.new("Frame")
	bar.Name = "TopBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 6)
	bar.Size = UDim2.new(0.6, 0, 0, 44)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	bar.BackgroundTransparency = 0.35
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bar
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 44)
	sizeLimit.Parent = bar

	local teamLabels: { [string]: TextLabel } = {}
	for i, t in Config.Teams do
		local x = if i == 1 then 0 else 0.65
		teamLabels[t.id] = label(bar, {
			Name = t.id,
			Position = UDim2.fromScale(x + 0.02, 0.1),
			Size = UDim2.fromScale(0.31, 0.8),
			TextColor3 = BrickColor.new(t.color :: any).Color,
			TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		})
	end
	local clock = label(bar, {
		Name = "Clock",
		Position = UDim2.fromScale(0.35, 0.05),
		Size = UDim2.fromScale(0.3, 0.6),
	})
	local phase = label(bar, {
		Name = "Phase",
		Position = UDim2.fromScale(0.35, 0.62),
		Size = UDim2.fromScale(0.3, 0.33),
		Font = Enum.Font.GothamBold,
	})

	local announce = label(gui, {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 54),
		Size = UDim2.new(0.45, 0, 0, 18),
		Text = "",
	})
	local announceLimit = Instance.new("UISizeConstraint")
	announceLimit.MaxSize = Vector2.new(420, 18)
	announceLimit.Parent = announce

	local carrying = label(gui, {
		Name = "Carrying",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.new(0.6, 0, 0, 30),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 220, 90),
	})

	gui.Parent = player:WaitForChild("PlayerGui")

	local announceToken = 0
	local announceEvent = remotes:WaitForChild(Net.Announce) :: RemoteEvent
	announceEvent.OnClientEvent:Connect(function(text: string)
		announceToken += 1
		local mine = announceToken
		announce.Text = text
		task.delay(4, function()
			if announceToken == mine then
				announce.Text = ""
			end
		end)
	end)

	local phaseText = {
		Waiting = "Waiting for players",
		Intermission = "Starting in",
		Playing = "Bring food home!",
		PostMatch = "Match over",
	}

	while true do
		local goal = state:GetAttribute("PointsToWin") or Config.PointsToWin
		for _, t in Config.Teams do
			local score = state:GetAttribute("Score_" .. t.id) or 0
			teamLabels[t.id].Text = string.format("%s %d/%d", string.upper(t.id), score, goal)
		end

		local p = state:GetAttribute("Phase") or "Waiting"
		local endsAt = state:GetAttribute("PhaseEndsAt") or 0
		local left = if endsAt > 0 then endsAt - Workspace:GetServerTimeNow() else 0
		clock.Text = if endsAt > 0 then formatTime(left) else "--:--"
		if p == "PostMatch" then
			local winner = state:GetAttribute("Winner")
			phase.Text = if winner == "Draw" then "Draw!" else tostring(winner) .. " wins!"
		else
			phase.Text = phaseText[p] or p
		end

		-- The "follow the beam home" pill (GameFeel) covers the carry message now.
		carrying.Text = ""

		task.wait(0.2)
	end
end

return Hud
