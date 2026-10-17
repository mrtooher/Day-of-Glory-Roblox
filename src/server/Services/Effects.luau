--!strict
-- Server-simulated projectiles, grease traps and simple visual flashes.
-- Projectiles are anchored Parts moved on Heartbeat, so hits are decided by
-- the server, not by client physics.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

local Effects = {}

local StatusService: any
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

-- Enemies of `owner` within `radius` of `pos` that can currently be hit.
-- A vanished enemy can't be targeted unless Dog's SNIFF revealed it.
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
	else
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.3, 2.5, 2.5)
		p.Color = Color3.fromRGB(255, 170, 60)
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
	p.Color = Color3.fromRGB(230, 220, 120)
	p.Material = Enum.Material.Glass
	p.Transparency = 0.3
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
