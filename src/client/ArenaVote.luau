--!strict
-- Arena vote panel (Jim 2026-11-04): while waiting and during the countdown,
-- tap the arena you want next. Most votes wins, tie = random, no votes keeps
-- the current arena (server decides: MatchService + Shared/Rules/ArenaVote).
-- Sits under the score bar; hidden while the character picker is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ArenaVote = require(ReplicatedStorage.Shared.Rules.ArenaVote)

local ArenaVotePanel = {}

local GOLD = Color3.fromRGB(255, 200, 60)
local COLORS: { [string]: Color3 } = {
	City = Color3.fromRGB(70, 80, 105),
	Water = Color3.fromRGB(0, 130, 175),
}

function ArenaVotePanel.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local state = ReplicatedStorage:WaitForChild(Net.MatchStateFolder)
	local remotes = ReplicatedStorage:WaitForChild(Net.RemotesFolder)
	local voteEvent = remotes:WaitForChild(Net.RequestArenaVote) :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "ArenaVote"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 76) -- under the score bar and announcements
	panel.Size = UDim2.new(0.9, 0, 0, 58)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	panel.BackgroundTransparency = 0.2
	panel.Visible = false
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 58)
	limit.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 2)
	title.Size = UDim2.new(1, 0, 0, 16)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.Text = "VOTE FOR THE ARENA"
	title.Parent = panel

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 6, 0, 20)
	row.Size = UDim2.new(1, -12, 1, -24)
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local n = #Config.Arenas
	type Btn = { id: string, name: string, button: TextButton, stroke: UIStroke }
	local buttons: { Btn } = {}
	local myVote: string? = nil

	for i, a in Config.Arenas do
		local b = Instance.new("TextButton")
		b.Name = a.id
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0)
		b.BackgroundColor3 = COLORS[a.id] or Color3.fromRGB(60, 60, 75)
		b.AutoButtonColor = true
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = a.displayName
		b.Parent = row
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.Parent = b
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = GOLD
		s.Thickness = 3
		s.Enabled = false
		s.Parent = b
		b.Activated:Connect(function()
			myVote = a.id
			voteEvent:FireServer(a.id)
		end)
		table.insert(buttons, { id = a.id, name = a.displayName, button = b, stroke = s })
	end

	gui.Parent = playerGui

	local lastPhase: string? = nil
	while true do
		local phase = state:GetAttribute("Phase") or "Waiting"
		if phase ~= lastPhase then
			if not ArenaVote.canVote(phase) then
				myVote = nil -- votes are cleared when the match starts
			end
			lastPhase = phase
		end

		local picker = playerGui:FindFirstChild("CharacterSelect")
		local pickerPanel = picker and picker:FindFirstChild("Panel")
		local pickerOpen = pickerPanel ~= nil and (pickerPanel :: GuiObject).Visible

		local voting = state:GetAttribute("ArenaVoting") == true
		panel.Visible = voting and ArenaVote.canVote(phase) and not pickerOpen

		if panel.Visible then
			local current = state:GetAttribute("Arena")
			for _, b in buttons do
				local votes = state:GetAttribute("ArenaVotes_" .. b.id) or 0
				local mark = if myVote == b.id then "✓ " else ""
				local now = if current == b.id then " (NOW)" else ""
				b.button.Text = string.format("%s%s%s  %d", mark, b.name, now, votes)
				b.stroke.Enabled = myVote == b.id
			end
		end
		task.wait(0.15)
	end
end

return ArenaVotePanel
