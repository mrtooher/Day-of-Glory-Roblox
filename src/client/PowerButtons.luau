--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local PowerButtons = {}
local ACTION = "UsePower"

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
	button.Size = UDim2.fromOffset(120, 60)
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

	gui.Parent = player:WaitForChild("PlayerGui")

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