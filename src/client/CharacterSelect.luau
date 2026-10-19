--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local CharacterSelect = {}

local names: { [string]: string } = {
	Kelly = "Kelly", Sol = "Sol", Vex = "Vex", Pim = "Pim",
	Cop = "Cop", Dog = "Dog", PizzaMan = "Pizza Man", Cook = "Cook",
}

function CharacterSelect.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(Net.RemotesFolder)
	local request = remotes:WaitForChild(Net.RequestCharacter) :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "CharacterSelect"
	gui.ResetOnSpawn = false

	local openBtn = Instance.new("TextButton")
	openBtn.Name = "Open"
	openBtn.AnchorPoint = Vector2.new(0, 1)
	openBtn.Position = UDim2.new(0, 10, 1, -10)
	openBtn.Size = UDim2.fromOffset(140, 44)
	openBtn.Font = Enum.Font.GothamBlack
	openBtn.TextScaled = true
	openBtn.Text = "CHARACTER"
	openBtn.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
	openBtn.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.6)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 360)
	limit.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -60, 0, 30) -- leave room for the X
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.Text = "Pick a character (max 2 per team)"
	status.Parent = panel

	-- FIX: Added Close (X) button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -6, 0, 4)
	closeBtn.Size = UDim2.fromOffset(40, 40)
	closeBtn.ZIndex = 10 -- always drawn above the title and grid
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextScaled = true
	closeBtn.Text = "X"
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Parent = panel

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Position = UDim2.new(0, 0, 0, 36)
	grid.Size = UDim2.new(1, 0, 1, -36)
	grid.BackgroundTransparency = 1
	grid.Parent = panel
	
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.25, -8, 0.5, -8)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	-- The CHARACTER button doubles as a close button while the panel is open.
	local function setOpen(open: boolean)
		panel.Visible = open
		openBtn.Text = if open then "CLOSE" else "CHARACTER"
	end

	local function closePanel()
		setOpen(false)
	end

	closeBtn.Activated:Connect(closePanel)

	openBtn.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)

	-- FIX: Bind Esc and Gamepad B to close the panel
	ContextActionService:BindAction("CloseCharacterSelect", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and panel.Visible then
			closePanel()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)

	for i, c in Config.Characters do
		local b = Instance.new("TextButton")
		b.Name = c.id
		b.LayoutOrder = i
		b.Font = Enum.Font.GothamBlack
		b.TextScaled = true
		b.TextWrapped = true
		b.BackgroundColor3 = Color3.fromRGB(70, 70, 95)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = string.format("%s\n%s", names[c.id] or c.id, Config.Powers[c.power].displayName)
		b.Parent = grid
		b.Activated:Connect(function()
			request:FireServer(c.id)
			closePanel() -- FIX: Close panel when a character is picked
		end)
	end

	local function refresh()
		local current = player:GetAttribute("CharacterId")
		local err = player:GetAttribute("SelectError")
		if type(err) == "string" and err ~= "" then
			status.Text = err
		elseif type(current) == "string" then
			status.Text = "You are " .. (names[current] or current)
		end
		for _, child in grid:GetChildren() do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = if child.Name == current
					then Color3.fromRGB(255, 170, 40)
					else Color3.fromRGB(70, 70, 95)
			end
		end
	end
	
	player:GetAttributeChangedSignal("CharacterId"):Connect(refresh)
	player:GetAttributeChangedSignal("SelectError"):Connect(refresh)
	refresh()

	gui.Parent = player:WaitForChild("PlayerGui")
end

return CharacterSelect