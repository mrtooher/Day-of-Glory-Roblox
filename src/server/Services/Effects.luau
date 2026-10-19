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

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local rng = Random.new()

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

-- Looks ---------------------------------------------------------------------
-- Every visual part is Anchored and non-colliding/non-queryable/non-touchable.
-- Multi-part looks are a Model that is moved with PivotTo, so nothing is left
-- behind: destroying the visual removes all of it.

local function visualPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Flat disc (cylinder lying down) at `offset` from the model origin, `y` up.
local function flatDisc(
	parent: Instance,
	offset: Vector3,
	diameter: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	transparency: number
): Part
	local d = visualPart()
	d.Shape = Enum.PartType.Cylinder
	d.Size = Vector3.new(thickness, diameter, diameter)
	d.CFrame = CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90))
	d.Color = color
	d.Material = material
	d.Transparency = transparency
	d.Parent = parent
	return d
end

local function thinTrail(part: Part, c0: Color3, c1: Color3, lifetime: number, halfWidth: number): Trail
	local trail = Instance.new("Trail")
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, halfWidth, 0)
	att0.Parent = part
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -halfWidth, 0)
	att1.Parent = part
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(c0, c1)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Lifetime = lifetime
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = part
	return trail
end

-- Fireball: glowing orange core, licking flames, hot light, long fiery trail.
local function buildFireball(): Part
	local p = visualPart()
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.8, 1.8, 1.8)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 120, 30)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 50)
	light.Brightness = 3
	light.Range = 14
	light.Parent = p

	local flames = Instance.new("ParticleEmitter")
	flames.Color = ColorSequence.new(Color3.fromRGB(255, 210, 70), Color3.fromRGB(255, 50, 0))
	flames.Size = NumberSequence.new(2.6, 0.3)
	flames.Transparency = NumberSequence.new(0.1, 1)
	flames.Lifetime = NumberRange.new(0.25, 0.5)
	flames.Speed = NumberRange.new(1, 4)
	flames.SpreadAngle = Vector2.new(180, 180)
	flames.LightEmission = 1
	flames.Rate = 70
	flames.Parent = p

	thinTrail(p, Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 40, 0), 0.4, 0.9)
	return p
end

-- Stun gun: crackling electric orb (white-hot core, blue energy shell, spinning
-- spark star), shedding sparks behind it. Returns the model.
local function buildStunBolt(): Model
	local model = Instance.new("Model")
	local core = visualPart()
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1.2, 1.2, 1.2)
	core.Color = Color3.fromRGB(255, 245, 120)
	core.Material = Enum.Material.Neon
	core.Parent = model
	model.PrimaryPart = core

	local shell = visualPart()
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(2.6, 2.6, 2.6)
	shell.Color = Color3.fromRGB(110, 200, 255)
	shell.Material = Enum.Material.ForceField
	shell.Transparency = 0.25
	shell.Parent = model

	-- Spark star: 3 bars in the horizontal plane + 1 vertical, spinning with the model.
	for i = 0, 2 do
		local bar = visualPart()
		bar.Size = Vector3.new(0.14, 0.14, 3.6)
		bar.CFrame = CFrame.Angles(0, math.rad(i * 60), 0)
		bar.Color = if i % 2 == 0 then Color3.fromRGB(255, 255, 200) else Color3.fromRGB(150, 225, 255)
		bar.Material = Enum.Material.Neon
		bar.Parent = model
	end
	local vbar = visualPart()
	vbar.Size = Vector3.new(0.14, 3.2, 0.14)
	vbar.Color = Color3.fromRGB(255, 255, 200)
	vbar.Material = Enum.Material.Neon
	vbar.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 120)
	light.Brightness = 3
	light.Range = 12
	light.Parent = core

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 245, 100), Color3.fromRGB(120, 210, 255))
	sparks.Size = NumberSequence.new(0.8, 0)
	sparks.Transparency = NumberSequence.new(0, 1)
	sparks.Lifetime = NumberRange.new(0.2, 0.4)
	sparks.Speed = NumberRange.new(4, 10)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Rate = 90
	sparks.Parent = core

	thinTrail(core, Color3.fromRGB(255, 255, 160), Color3.fromRGB(120, 200, 255), 0.35, 0.5)
	return model
end

-- Pizza: golden crust disc, red sauce, a few pepperoni and cheese bits, with
-- crumbs shed behind it. Built flat around the origin (Y up) so a spin about
-- Y looks like a thrown frisbee. Returns the model.
local function buildPizza(): Model
	local model = Instance.new("Model")
	local pivot = visualPart()
	pivot.Size = Vector3.new(0.4, 0.4, 0.4)
	pivot.Transparency = 1
	pivot.Parent = model
	model.PrimaryPart = pivot

	flatDisc(model, Vector3.zero, 3.6, 0.5, Color3.fromRGB(235, 165, 70), Enum.Material.SmoothPlastic, 0)
	flatDisc(model, Vector3.new(0, 0.27, 0), 3.0, 0.1, Color3.fromRGB(205, 40, 28), Enum.Material.SmoothPlastic, 0)
	flatDisc(model, Vector3.new(0, 0.32, 0), 2.5, 0.06, Color3.fromRGB(255, 205, 70), Enum.Material.SmoothPlastic, 0.1)
	local spots = {
		Vector3.new(0, 0, 0),
		Vector3.new(0.8, 0, 0.3),
		Vector3.new(-0.7, 0, 0.6),
		Vector3.new(0.1, 0, -0.9),
		Vector3.new(-0.6, 0, -0.5),
		Vector3.new(0.7, 0, -0.5),
	}
	for _, s in spots do
		flatDisc(model, s + Vector3.new(0, 0.4, 0), 0.7, 0.12, Color3.fromRGB(150, 28, 28), Enum.Material.SmoothPlastic, 0)
	end

	local crumbs = Instance.new("ParticleEmitter")
	crumbs.Color = ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(220, 50, 30))
	crumbs.Size = NumberSequence.new(0.7, 0)
	crumbs.Transparency = NumberSequence.new(0, 1)
	crumbs.Lifetime = NumberRange.new(0.3, 0.6)
	crumbs.Speed = NumberRange.new(1, 5)
	crumbs.SpreadAngle = Vector2.new(180, 180)
	crumbs.Rate = 40
	crumbs.Parent = pivot
	return model
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

	-- `visual` is one Part or one Model; `frame` says where/how to hold it at
	-- `pos` after `spin` radians of spinning.
	local visual: PVInstance
	local frame: (pos: Vector3, spin: number) -> CFrame
	if spec.kind == "Fireball" then
		visual = buildFireball()
		frame = function(pos, spin)
			return CFrame.new(pos) * CFrame.Angles(0, spin, 0)
		end
	elseif spec.kind == "Whistle" then
		visual = buildStunBolt()
		frame = function(pos, spin)
			return CFrame.new(pos) * CFrame.Angles(0, spin * 1.5, 0)
		end
	elseif spec.kind == "PizzaToss" then
		visual = buildPizza()
		frame = function(pos, spin)
			-- Nose-up tilt, spinning flat like a frisbee.
			return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(-12), 0, 0) * CFrame.Angles(0, spin * 1.6, 0)
		end
	else
		local p = visualPart()
		visual = p
		frame = function(pos, spin)
			return CFrame.new(pos) * CFrame.Angles(0, spin, math.rad(90))
		end
	end
	visual.Name = spec.kind

	local start = owner.root.Position + dir * 3
	local traveled = 0
	local spin = 0
	visual:PivotTo(frame(start, 0))
	visual.Parent = folder

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		traveled += spec.speed * dt
		spin += dt * 12
		local pos = start + dir * traveled
		visual:PivotTo(frame(pos, spin))
		local hit = Effects.enemiesNear(owner, pos, Config.ProjectileHitRadius)[1]
		if hit or traveled >= spec.range then
			conn:Disconnect()
			visual:Destroy()
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

-- Grease puddle: layered shiny glass/foil blobs in yellow-brown, glassy bubbles
-- sitting in it, more bubbles rising and the odd glint. Covers exactly `radius`.
local function buildGreasePuddle(center: Vector3, radius: number): Model
	local model = Instance.new("Model")
	local d = radius * 2
	local y = center.Y

	local base = flatDisc(model, Vector3.new(center.X, y - 0.03, center.Z), d, 0.16, Color3.fromRGB(150, 105, 30), Enum.Material.Glass, 0.2)
	base.Reflectance = 0.25
	model.PrimaryPart = base
	local mid = flatDisc(
		model,
		Vector3.new(center.X + radius * 0.12, y + 0.01, center.Z + radius * 0.08),
		d * 0.8,
		0.16,
		Color3.fromRGB(215, 170, 55),
		Enum.Material.Foil,
		0.15
	)
	mid.Reflectance = 0.2
	local shine = flatDisc(
		model,
		Vector3.new(center.X - radius * 0.2, y + 0.05, center.Z - radius * 0.15),
		d * 0.42,
		0.16,
		Color3.fromRGB(255, 228, 120),
		Enum.Material.Glass,
		0.3
	)
	shine.Reflectance = 0.4

	-- Bubbles sitting in the grease.
	for _ = 1, 5 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(0.1, 0.7) * radius
		local size = rng:NextNumber(0.6, 1.3)
		local b = visualPart()
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.one * size
		b.CFrame = CFrame.new(center.X + math.cos(ang) * dist, y + 0.1 + size * 0.2, center.Z + math.sin(ang) * dist)
		b.Color = Color3.fromRGB(255, 240, 150)
		b.Material = Enum.Material.Glass
		b.Transparency = 0.35
		b.Reflectance = 0.5
		b.Parent = model
	end

	-- Invisible host spanning the puddle for rising bubbles and glints.
	local host = visualPart()
	host.Size = Vector3.new(d * 0.8, 0.2, d * 0.8)
	host.CFrame = CFrame.new(center.X, y + 0.2, center.Z)
	host.Transparency = 1
	host.Parent = model

	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = SMOKE_TEXTURE
	bubbles.Color = ColorSequence.new(Color3.fromRGB(255, 245, 160), Color3.fromRGB(255, 255, 225))
	bubbles.Size = NumberSequence.new(0.5, 1)
	bubbles.Transparency = NumberSequence.new(0.4, 1)
	bubbles.Lifetime = NumberRange.new(1, 1.7)
	bubbles.Speed = NumberRange.new(1, 2.5)
	bubbles.SpreadAngle = Vector2.new(15, 15)
	bubbles.Rate = 4
	bubbles.Parent = host

	local glints = Instance.new("ParticleEmitter")
	glints.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	glints.Size = NumberSequence.new(0.9, 0)
	glints.Transparency = NumberSequence.new(0, 1)
	glints.Lifetime = NumberRange.new(0.5, 0.9)
	glints.Speed = NumberRange.new(0, 1)
	glints.LightEmission = 1
	glints.Rate = 1.5
	glints.Parent = host
	return model
end

function Effects.placeTrap(owner: Actor, spec: TrapSpec)
	local feet = owner.root.Position - Vector3.new(0, owner.humanoid.HipHeight + owner.root.Size.Y / 2, 0)
	local center = Vector3.new(feet.X, 0.15, feet.Z)

	local p: PVInstance
	if spec.kind == "GreaseSpill" then
		p = buildGreasePuddle(center, spec.radius)
	else
		local disc = visualPart()
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.2, spec.radius * 2, spec.radius * 2)
		disc.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
		disc.Color = Color3.fromRGB(230, 220, 120)
		disc.Material = Enum.Material.Glass
		disc.Transparency = 0.3
		p = disc
	end
	p.Name = spec.kind
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
					-- Splash/"SLOWED!" only for the enemies the grease actually affects.
					if a.team ~= owner.team then
						local announcement = if spec.kind == "GreaseSpill" then "SLOWED!" else nil
						Remotes.event(Net.PlayPowerFx):FireAllClients(a.model, spec.kind, { action = "trap_enter", announcement = announcement })
					end
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
