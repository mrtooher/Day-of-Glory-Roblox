--!strict
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require(script.Parent.Remotes)
local Actors = require(script.Parent.Actors)
local StatusService: any
type Actor = Actors.Actor

local Effects = {}
local folder: Folder
local trapsByOwner: { [string]: number } = {}

function Effects.init(services)
	StatusService = services.StatusService
end

function Effects.start()
	folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = Workspace
end

function Effects.enemiesNear(owner: Actor, pos: Vector3, radius: number): { Actor }
	local now = Actors.now()
	local revealed = StatusService.isRevealedTo(owner.team, now)
	local list = {}
	for _, a in Actors.all() do
		if a.team ~= owner.team and (revealed or not Actors.isVanished(a, now)) then
			if (Actors.position(a) - pos).Magnitude <= radius then
				table.insert(list, a)
			end
		end
	end
	return list
end

function Effects.flash(pos: Vector3, radius: number, color: Color3)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * radius * 2
	p.Position = pos
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.ForceField
	p.Color = color
	p.Transparency = 0.3
	p.Parent = folder
	Debris:AddItem(p, 0.4)
end

type ProjectileSpec = {
	kind: string,
	speed: number,
	range: number,
	onHit: (target: any) -> (),
}

function Effects.launchProjectile(owner: Actor, spec: ProjectileSpec)
	local look = owner.root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)

	local p = Instance.new("Part")
	p.Name = spec.kind
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if spec.kind == "Fireball" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.5, 1.5, 1.5)
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 110, 30)
		
		local trail = Instance.new("Trail")
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 50, 0))
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Lifetime = 0.3
		trail.Parent = p
		local att0 = Instance.new("Attachment")
		att0.Parent = p
		local att1 = Instance.new("Attachment")
		att1.Position = Vector3.new(0, 0, -1.5)
		att1.Parent = p
		trail.Attachment0 = att0
		trail.Attachment1 = att1
	elseif spec.kind == "Whistle" then
		-- Stun gun bolt: bright electric-yellow ball with a long glowing trail.
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.2, 1.2, 1.2)
		p.Color = Color3.fromRGB(255, 245, 90)
		p.Material = Enum.Material.Neon

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 240, 120)
		light.Brightness = 3
		light.Range = 10
		light.Parent = p

		local trail = Instance.new("Trail")
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 160), Color3.fromRGB(120, 200, 255))
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Lifetime = 0.35
		trail.LightEmission = 1
		trail.FaceCamera = true
		local att0 = Instance.new("Attachment")
		att0.Position = Vector3.new(0, 0.4, 0)
		att0.Parent = p
		local att1 = Instance.new("Attachment")
		att1.Position = Vector3.new(0, -0.4, 0)
		att1.Parent = p
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.Parent = p
	elseif spec.kind == "PizzaToss" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.2, 2, 2)
		p.Color = Color3.fromRGB(255, 170, 60)
		p.Material = Enum.Material.SmoothPlastic
	end

	local start = owner.root.Position + dir * 3
	local traveled = 0
	local spin = 0
	p.CFrame = CFrame.new(start)
	p.Parent = folder

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		traveled += spec.speed * dt
		spin += dt * 12
		local pos = start + dir * traveled
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, spin, math.rad(90))
		local hit = Effects.enemiesNear(owner, pos, Config.ProjectileHitRadius)[1]
		if hit or traveled >= spec.range then
			conn:Disconnect()
			p:Destroy()
			if hit then
				spec.onHit(Actors.view(hit))
				local announcement = if spec.kind == "Fireball" or spec.kind == "Whistle" then "STUNNED!" elseif spec.kind == "PizzaToss" then "SLOWED!" else nil
				Remotes.event(Net.PlayPowerFx):FireAllClients(hit.model, spec.kind, { action = "hit", announcement = announcement })
			end
		end
	end)
end

type TrapSpec = {
	kind: string,
	radius: number,
	lifetimeSeconds: number,
	onEnter: (target: any) -> (),
}

function Effects.activeTraps(owner: Actor): number
	return trapsByOwner[owner.id] or 0
end

function Effects.placeTrap(owner: Actor, spec: TrapSpec)
	local feet = owner.root.Position - Vector3.new(0, owner.humanoid.HipHeight + owner.root.Size.Y / 2, 0)
	local center = Vector3.new(feet.X, 0.15, feet.Z)

	local p = Instance.new("Part")
	p.Name = spec.kind
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.2, spec.radius * 2, spec.radius * 2)
	p.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if spec.kind == "GreaseSpill" then
		p.Color = Color3.fromRGB(180, 160, 50)
		p.Material = Enum.Material.Glass
		p.Transparency = 0.4
	else
		p.Color = Color3.fromRGB(230, 220, 120)
		p.Material = Enum.Material.Glass
		p.Transparency = 0.3
	end
	p.Parent = folder

	trapsByOwner[owner.id] = (trapsByOwner[owner.id] or 0) + 1
	local inside: { [string]: boolean } = {}

	local conn = RunService.Heartbeat:Connect(function()
		local now: { [string]: boolean } = {}
		for _, a in Actors.all() do
			local pos = Actors.position(a)
			if Vector3.new(pos.X - center.X, 0, pos.Z - center.Z).Magnitude <= spec.radius then
				now[a.id] = true
				if not inside[a.id] then
					spec.onEnter(Actors.view(a))
					local announcement = if spec.kind == "GreaseSpill" then "SLOWED!" else nil
					Remotes.event(Net.PlayPowerFx):FireAllClients(a.model, spec.kind, { action = "trap_enter", announcement = announcement })
				end
			end
		end
		inside = now
	end)

	task.delay(spec.lifetimeSeconds, function()
		conn:Disconnect()
		p:Destroy()
		trapsByOwner[owner.id] = math.max(0, (trapsByOwner[owner.id] or 1) - 1)
	end)
end

return Effects