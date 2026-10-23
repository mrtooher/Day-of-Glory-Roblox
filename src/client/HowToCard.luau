--!strict
-- "HOW TO PLAY" card (Jim 2026-10-22: players couldn't figure out how to play).
-- Opens by itself while waiting and during the countdown; closes when the
-- match starts. The HOW TO PLAY button (bottom-left, right of SOUND) opens or
-- closes it any time. Hidden while the character picker is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local HowTo = require(ReplicatedStorage.Shared.Rules.HowTo)

local HowToCard = {}

function HowToCard.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local state = ReplicatedStorage:WaitForChild(Net.MatchStateFolder)

	local gui = Instance.new("ScreenGui")
	gui.Name = "HowToPlay"
	gui.ResetOnSpawn = false

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.9, 0.62)
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	card.BackgroundTransparency = 0.15
	card.Visible = false
	card.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 330)
	limit.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 190, 60)
	stroke.Thickness = 2
	stroke.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -50, 0, 34)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.Text = "HOW TO PLAY"
	title.Parent = card

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, 6, 0, -2)
	closeBtn.Size = UDim2.fromOffset(40, 40)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextScaled = true
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Text = "X"
	closeBtn.Parent = card
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 0, 0, 40)
	body.Size = UDim2.new(1, 0, 1, -40)
	body.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	local lines = HowTo.lines(Config)
	for i, text in lines do
		local line = Instance.new("TextLabel")
		line.LayoutOrder = i
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 1 / #lines, -4)
		line.Font = if i == #lines then Enum.Font.GothamBlack else Enum.Font.GothamBold
		line.TextScaled = true
		line.TextWrapped = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = if i == #lines then Color3.fromRGB(255, 220, 80) else Color3.new(1, 1, 1)
		line.Text = text
		line.Parent = body
	end

	local openBtn = Instance.new("TextButton")
	openBtn.Name = "HowToButton"
	openBtn.AnchorPoint = Vector2.new(0, 1)
	openBtn.Position = UDim2.new(0, 290, 1, -10) -- right of the SOUND button
	openBtn.Size = UDim2.fromOffset(120, 44)
	openBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	openBtn.BackgroundTransparency = 0.25
	openBtn.Font = Enum.Font.GothamBlack
	openBtn.TextScaled = true
	openBtn.TextColor3 = Color3.new(1, 1, 1)
	openBtn.Text = "HOW TO PLAY"
	openBtn.Parent = gui
	local openCorner = Instance.new("UICorner")
	openCorner.CornerRadius = UDim.new(0, 10)
	openCorner.Parent = openBtn
	local openPad = Instance.new("UIPadding")
	openPad.PaddingLeft = UDim.new(0, 8)
	openPad.PaddingRight = UDim.new(0, 8)
	openPad.Parent = openBtn

	gui.Parent = playerGui

	-- override: nil = follow the phase; true/false = the player's choice,
	-- kept until the phase changes.
	local override: boolean? = nil
	local lastPhase: string? = nil
	local wanted = false

	closeBtn.Activated:Connect(function()
		override = false
	end)
	openBtn.Activated:Connect(function()
		override = not wanted
	end)

	while true do
		local phase = state:GetAttribute("Phase") or "Waiting"
		if phase ~= lastPhase then
			override = nil
			lastPhase = phase
		end
		wanted = if override ~= nil then override else HowTo.cardAutoVisible(phase)

		local picker = playerGui:FindFirstChild("CharacterSelect")
		local pickerPanel = picker and picker:FindFirstChild("Panel")
		local pickerOpen = pickerPanel ~= nil and (pickerPanel :: GuiObject).Visible

		card.Visible = wanted and not pickerOpen
		openBtn.Text = if wanted then "CLOSE HELP" else "HOW TO PLAY"
		task.wait(0.15)
	end
end

return HowToCard
