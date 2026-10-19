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

	-- FIX: Create a dedicated GUI button to ensure visibility across all devices and Studio
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
	button.Text = "POWER"
	button.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
	button.TextColor3 = Color3.fromRGB(30, 30, 30)
	button.Parent = gui

	-- Handle touch/mouse clicks directly
	button.MouseButton1Click:Connect(function()
		request:FireServer()
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Bind keyboard and gamepad inputs
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
		end, false, table.unpack(keys)) -- false: we manage our own touch button
	end

	-- Update button text with power name or cooldown
	local lastTitle = ""
	while true do
		local title = "POWER"
		local character = player.Character
		if character then
			local powerId = character:GetAttribute("PowerId")
			local readyAt = character:GetAttribute("PowerReadyAt") or 0
			local cfg = if type(powerId) == "string" then Config.Powers[powerId] else nil
			if cfg then
				local left = readyAt - Workspace:GetServerTimeNow()
				title = if left > 0 then string.format("%d", math.ceil(left)) else cfg.displayName
			end
		end
		if title ~= lastTitle then
			button.Text = title
			ContextActionService:SetTitle(ACTION, title)
			lastTitle = title
		end
		task.wait(0.1)
	end
end

return PowerButtons
