--!strict
-- Power button: on-screen touch button (phones/tablets), Q on keyboard,
-- X on gamepad. Shows the power name and the cooldown countdown.

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

	local keys: { Enum.KeyCode } = {}
	for _, name in Config.PowerKeys do
		table.insert(keys, (Enum.KeyCode :: any)[name])
	end

	ContextActionService:BindAction(ACTION, function(_name, inputState, _input)
		if inputState == Enum.UserInputState.Begin then
			request:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, true, table.unpack(keys))
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -150, 1, -150))

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
			ContextActionService:SetTitle(ACTION, title)
			lastTitle = title
		end
		task.wait(0.1)
	end
end

return PowerButtons
