--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PowerLayout = require(ReplicatedStorage.Shared.Rules.PowerLayout)

local PowerButtons = {}
local ACTION = "UsePower"

local BUTTON_SIZE = Vector2.new(120, 60)
local JUMP_GAP = 10

-- Roblox's touch jump button (PlayerModule puts it in PlayerGui.TouchGui),
-- if it exists and is showing.
local function findJumpButton(playerGui: PlayerGui): GuiObject?
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jump and jump:IsA("GuiObject") and jump.Visible and jump.AbsoluteSize.X > 0 then
		return jump
	end
	return nil
end

-- Keep POWER above the jump button on touch screens; default bottom-right
-- corner otherwise. Re-runs when the jump button moves (rotation, resize).
local function keepClearOfJump(gui: ScreenGui, button: GuiObject, denied: GuiObject, playerGui: PlayerGui)
	local watched: GuiObject? = nil
	local conns: { RBXScriptConnection } = {}

	local function place()
		local jump = findJumpButton(playerGui)
		local jumpGui = jump and jump:FindFirstAncestorWhichIsA("ScreenGui")
		local x, y = nil, nil
		if jump and jumpGui then
			-- Same inset as the jump button's ScreenGui, so both use one origin.
			gui.IgnoreGuiInset = jumpGui.IgnoreGuiInset
			local p, s = jump.AbsolutePosition, jump.AbsoluteSize
			x, y = PowerLayout.aboveJump(
				{ x = p.X, y = p.Y, w = s.X, h = s.Y },
				{ x = gui.AbsoluteSize.X, y = gui.AbsoluteSize.Y },
				{ x = BUTTON_SIZE.X, y = BUTTON_SIZE.Y },
				JUMP_GAP
			)
		end
		if x and y then
			button.AnchorPoint = Vector2.new(0, 0)
			button.Position = UDim2.fromOffset(x, y)
			denied.AnchorPoint = Vector2.new(1, 1)
			denied.Position = UDim2.fromOffset(x + BUTTON_SIZE.X, y - 8)
		else
			button.AnchorPoint = Vector2.new(1, 1)
			button.Position = UDim2.new(1, -20, 1, -20)
			denied.AnchorPoint = Vector2.new(1, 1)
			denied.Position = UDim2.new(1, -20, 1, -88)
		end
	end

	local function watch()
		local touchGui = playerGui:FindFirstChild("TouchGui")
		local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
		if jump ~= watched then
			for _, c in conns do
				c:Disconnect()
			end
			table.clear(conns)
			watched = if jump and jump:IsA("GuiObject") then jump else nil
			if watched then
				for _, prop in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
					table.insert(conns, watched:GetPropertyChangedSignal(prop):Connect(place))
				end
			end
		end
		place()
	end

	playerGui.DescendantAdded:Connect(function(d)
		if d.Name == "JumpButton" or d.Name == "TouchGui" then
			task.defer(watch)
		end
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	watch()
end

function PowerButtons.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(Net.RemotesFolder)
	local request = remotes:WaitForChild(Net.RequestPower) :: RemoteEvent
	local state = ReplicatedStorage:WaitForChild(Net.MatchStateFolder)

	local gui = Instance.new("ScreenGui")
	gui.Name = "PowerButtonGui"
	gui.ResetOnSpawn = false

	local button = Instance.new("TextButton")
	button.Name = "PowerButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -20, 1, -20)
	button.Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y)
	button.Font = Enum.Font.GothamBlack
	button.TextScaled = true
	button.Text = "WAIT FOR MATCH"
	button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	button.TextColor3 = Color3.fromRGB(200, 200, 200)
	button.Parent = gui

	button.MouseButton1Click:Connect(function()
		request:FireServer()
	end)

	-- Short message above the button when the server says the power didn't fire.
	local denied = Instance.new("TextLabel")
	denied.Name = "DeniedMessage"
	denied.AnchorPoint = Vector2.new(1, 1)
	denied.Position = UDim2.new(1, -20, 1, -88)
	denied.Size = UDim2.fromOffset(260, 32)
	denied.BackgroundTransparency = 1
	denied.Font = Enum.Font.GothamBlack
	denied.TextScaled = true
	denied.TextColor3 = Color3.fromRGB(255, 90, 90)
	denied.TextStrokeTransparency = 0.3
	denied.TextXAlignment = Enum.TextXAlignment.Right
	denied.Text = ""
	denied.Parent = gui
	local deniedToken = 0
	local deniedEvent = remotes:WaitForChild(Net.PowerDenied) :: RemoteEvent
	deniedEvent.OnClientEvent:Connect(function(message: string)
		deniedToken += 1
		local mine = deniedToken
		denied.Text = message
		task.delay(1.5, function()
			if deniedToken == mine then
				denied.Text = ""
			end
		end)
	end)

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	gui.Parent = playerGui
	keepClearOfJump(gui, button, denied, playerGui)

	local keys: { Enum.KeyCode } = {}
	for _, name in Config.PowerKeys do
		local keyCode = (Enum.KeyCode :: any)[name]
		if keyCode then
			table.insert(keys, keyCode)
		end
	end

	if #keys > 0 then
		ContextActionService:BindAction(ACTION, function(_name, inputState, _input)
			if inputState == Enum.UserInputState.Begin then
				request:FireServer()
			end
			return Enum.ContextActionResult.Sink
		end, false, table.unpack(keys))
	end

	local lastTitle = ""
	local lastBgColor = Color3.fromRGB(100, 100, 100)
	
	while true do
		local title = "WAIT FOR MATCH"
		local bgColor = Color3.fromRGB(100, 100, 100)
		local textColor = Color3.fromRGB(200, 200, 200)
		
		local phase = state:GetAttribute("Phase")
		if phase == "Playing" then
			local character = player.Character
			if character then
				local powerId = character:GetAttribute("PowerId")
				local readyAt = character:GetAttribute("PowerReadyAt") or 0
				local cfg = if type(powerId) == "string" then Config.Powers[powerId] else nil
				if cfg then
					local now = Workspace:GetServerTimeNow()
					local left = readyAt - now
					if left > 0 then
						title = string.format("%d", math.ceil(left))
						bgColor = Color3.fromRGB(80, 80, 80)
						textColor = Color3.fromRGB(255, 100, 100)
					else
						title = cfg.displayName
						bgColor = Color3.fromRGB(255, 190, 60)
						textColor = Color3.fromRGB(30, 30, 30)
					end
				end
			end
		end
		
		if title ~= lastTitle or bgColor ~= lastBgColor then
			button.Text = title
			button.BackgroundColor3 = bgColor
			button.TextColor3 = textColor
			ContextActionService:SetTitle(ACTION, title)
			lastTitle = title
			lastBgColor = bgColor
		end
		task.wait(0.1)
	end
end

return PowerButtons