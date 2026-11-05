--!strict
-- Splashes while wading (Jim 2026-11-04: Water World water should do
-- something). The server sets the "Wading" attribute on a character standing
-- in knee-deep water (StatusService + Shared/Rules/Wading); here every client
-- sprays white droplets at the waterline while that character moves.
-- Visual only, no sound (Config.Audio has no splash id yet).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Splash = {}

local MOVING_SPEED = 3 -- studs/s of horizontal speed before it splashes

local function actorModels(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local bots = Workspace:FindFirstChild("Bots")
	if bots then
		for _, m in bots:GetChildren() do
			if m:IsA("Model") then
				table.insert(list, m)
			end
		end
	end
	return list
end

local emitters: { [Model]: ParticleEmitter } = setmetatable({}, { __mode = "k" }) :: any

-- Emitter on an attachment at the water surface under the root part.
local function emitterFor(model: Model, root: BasePart, humanoid: Humanoid): ParticleEmitter
	local existing = emitters[model]
	if existing and existing.Parent and existing.Parent.Parent == root then
		return existing
	end
	local att = Instance.new("Attachment")
	att.Name = "SplashAttachment"
	att.Position = Vector3.new(0, -(root.Size.Y / 2 + humanoid.HipHeight) + Config.Map.water.depth, 0)
	att.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Name = "WadeSplash"
	e.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
	e.LightEmission = 0.3
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	e.Lifetime = NumberRange.new(0.3, 0.5)
	e.Speed = NumberRange.new(5, 9)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -Workspace.Gravity * 0.6, 0)
	e.Rate = 40
	e.Enabled = false
	e.Parent = att
	emitters[model] = e
	return e
end

function Splash.start()
	while true do
		for _, model in actorModels() do
			local root = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid then
				local wading = model:GetAttribute("Wading") == true
				local v = root.AssemblyLinearVelocity
				local moving = Vector3.new(v.X, 0, v.Z).Magnitude > MOVING_SPEED
				if wading or emitters[model] then
					emitterFor(model, root, humanoid).Enabled = wading and moving
				end
			end
		end
		task.wait(0.1)
	end
end

return Splash
