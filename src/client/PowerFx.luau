--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)

local PowerFx = {}

local function createBigText(text: string, model: Model?)
	-- Only the player it happened to sees the big text.
	if model and model ~= Players.LocalPlayer.Character then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PowerAnnouncement"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.2)
	label.Position = UDim2.fromScale(0, 0.4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = gui
	
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.delay(1.5, function()
		gui:Destroy()
	end)
end

local function playActivateFx(model: Model, powerId: string)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local pos = root.Position

	if powerId == "Yell" then
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.5, Config.Powers.Yell.radius * 2, Config.Powers.Yell.radius * 2)
		ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 50, 50)
		ring.Transparency = 0
		ring.Parent = Workspace
		
		local shout = Instance.new("BillboardGui")
		shout.Name = "ShoutBubble"
		shout.Size = UDim2.fromOffset(100, 50)
		shout.StudsOffset = Vector3.new(0, 4, 0)
		shout.AlwaysOnTop = true
		shout.Adornee = root
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = "HEY!"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.5
		label.Parent = shout
		shout.Parent = root
		
		Debris:AddItem(ring, 0.5)
		Debris:AddItem(shout, 1.0)
		
	elseif powerId == "Vanish" then
		local function spawnSmoke()
			local smoke = Instance.new("ParticleEmitter")
			smoke.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
			smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
			smoke.Lifetime = NumberRange.new(0.5, 1.0)
			smoke.Rate = 50
			smoke.Parent = root
			task.delay(0.5, function()
				smoke.Enabled = false
				Debris:AddItem(smoke, 1.0)
			end)
		end
		spawnSmoke()
		
		local conn
		conn = root:GetAttributeChangedSignal("Vanished"):Connect(function()
			if root:GetAttribute("Vanished") == false then
				spawnSmoke()
				if conn then conn:Disconnect() end
			end
		end)
		
	elseif powerId == "SlowMo" then
		local bubble = Instance.new("Part")
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.one * Config.Powers.SlowMo.radius * 2
		bubble.Position = pos
		bubble.Anchored = true
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.CanTouch = false
		bubble.Material = Enum.Material.Glass
		bubble.Color = Color3.fromRGB(50, 150, 255)
		bubble.Transparency = 0.6
		bubble.Parent = Workspace
		Debris:AddItem(bubble, Config.Powers.SlowMo.durationSeconds)
		
	elseif powerId == "Sniff" then
		local lines = Instance.new("ParticleEmitter")
		lines.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		lines.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2) })
		lines.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		lines.Lifetime = NumberRange.new(0.3, 0.6)
		lines.Rate = 30
		lines.Speed = NumberRange.new(10, 20)
		lines.Parent = root
		task.delay(Config.Powers.Sniff.durationSeconds, function()
			lines.Enabled = false
			Debris:AddItem(lines, 1.0)
		end)
	end
end

local function playHitFx(model: Model, powerId: string, announcement: string?)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	if powerId == "Fireball" or powerId == "Whistle" then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50))
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		sparks.Lifetime = NumberRange.new(0.5, 1.0)
		sparks.Rate = 40
		sparks.Parent = root
		Debris:AddItem(sparks, 1.5)
		
		if powerId == "Fireball" then
			local stars = Instance.new("BillboardGui")
			stars.Name = "StunStars"
			stars.Size = UDim2.fromOffset(80, 80)
			stars.StudsOffset = Vector3.new(0, 4, 0)
			stars.AlwaysOnTop = true
			stars.Adornee = root
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.Text = "★"
			label.TextColor3 = Color3.fromRGB(255, 200, 0)
			label.Parent = stars
			stars.Parent = root
			Debris:AddItem(stars, 1.5)
		end
		
	elseif powerId == "PizzaToss" then
		local spark = Instance.new("ParticleEmitter")
		spark.Color = ColorSequence.new(Color3.fromRGB(255, 100, 50))
		spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
		spark.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		spark.Lifetime = NumberRange.new(0.3, 0.6)
		spark.Rate = 50
		spark.Parent = root
		Debris:AddItem(spark, 1.0)
	end

	if announcement then
		createBigText(announcement, model)
	end
end

function PowerFx.start()
	local remotes = ReplicatedStorage:WaitForChild(Net.RemotesFolder)
	local playFx = remotes:WaitForChild(Net.PlayPowerFx) :: RemoteEvent
	
	playFx.OnClientEvent:Connect(function(model: Model, powerId: string, data: any)
		local action = data.action or "activate"
		if action == "activate" then
			playActivateFx(model, powerId)
			if data.announcement then
				createBigText(data.announcement, model)
			end
		elseif action == "hit" or action == "trap_enter" then
			playHitFx(model, powerId, data.announcement)
		end
	end)
end

return PowerFx