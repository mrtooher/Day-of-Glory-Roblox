--!strict
-- Burger pickups on the field: touch for a short speed burst.
-- Dash pads (Arena parts named DashPad1..): run over one for a speed burst.
-- (Jump pads are client-side, see src/client/Pads.luau.)
-- Swim rings (Water World only, Jim 2026-11-05): grab an orange ring in the
-- lagoon for Config.Map.water.swimRing.seconds with no water slow.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor
local PadCooldown = require(ReplicatedStorage.Shared.Rules.PadCooldown)

local PickupService = {}

local StatusService: any
local MapServiceRef = MapService

type Ring = { position: Vector3, model: Model, readyAt: number }
local rings: { Ring } = {}
local ringFolder: Folder
-- Ring worn by an actor while the effect lasts (visual only).
local worn: { [Actor]: Model } = setmetatable({}, { __mode = "k" }) :: any

local RING_COLOR = Color3.fromRGB(255, 120, 30)

-- A swim ring made of beads in a circle (parts can't be hollow).
local function ringModel(name: string, diameter: number, bead: number): Model
	local m = Instance.new("Model")
	m.Name = name
	local n = 12
	local center = Instance.new("Part")
	center.Name = "RingCenter"
	center.Transparency = 1
	center.Size = Vector3.new(0.2, 0.2, 0.2)
	center.Anchored = true
	center.CanCollide = false
	center.CanQuery = false
	center.CanTouch = false
	center.Massless = true
	center.Parent = m
	m.PrimaryPart = center
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local b = Instance.new("Part")
		b.Name = "RingBead"
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(bead, bead, bead)
		b.Color = if i % 3 == 0 then Color3.new(1, 1, 1) else RING_COLOR
		b.Material = Enum.Material.SmoothPlastic
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Massless = true
		b.Anchored = false
		b.CFrame = center.CFrame * CFrame.new(math.cos(a) * diameter / 2, 0, math.sin(a) * diameter / 2)
		local w = Instance.new("WeldConstraint")
		w.Part0 = center
		w.Part1 = b
		w.Parent = b
		b.Parent = m
	end
	return m
end

type Pad = { position: Vector3, part: Part, readyAt: number }
local pads: { Pad } = {}

type DashPad = { name: string, position: Vector3 }
local dashPads: { DashPad } = {}
local padState = PadCooldown.new()

local TICK = 0.1

function PickupService.init(services)
	StatusService = services.StatusService
end

local function stepDashPads(now: number)
	local cfg = Config.Pads
	for _, a in Actors.all() do
		local pos = Actors.position(a)
		for _, pad in dashPads do
			local dx, dz = pos.X - pad.position.X, pos.Z - pad.position.Z
			if dx * dx + dz * dz <= cfg.radius * cfg.radius and math.abs(pos.Y - pad.position.Y) < 6 then
				if PadCooldown.tryUse(padState, a.id, pad.name, now, cfg.cooldownSeconds) then
					StatusService.apply(a, "boost", cfg.dashSeconds, cfg.dashMultiplier)
				end
			end
		end
	end
end

local function stepRings(now: number)
	local cfg = Config.Map.water.swimRing
	local active = MapServiceRef.currentArena() == "Water"
	for _, r in rings do
		local available = active and now >= r.readyAt
		local wantParent = if available then ringFolder else nil
		if r.model.Parent ~= wantParent then
			r.model.Parent = wantParent
		end
		if not available then
			continue
		end
		for _, a in Actors.all() do
			local pos = Actors.position(a)
			local dx, dz = pos.X - r.position.X, pos.Z - r.position.Z
			if dx * dx + dz * dz <= cfg.radius * cfg.radius and math.abs(pos.Y - r.position.Y) < 6 and a.humanoid.Health > 0 then
				a.model:SetAttribute("SwimRingUntil", now + cfg.seconds)
				r.readyAt = now + cfg.respawnSeconds
				r.model.Parent = nil
				print(string.format("[Ring] %s took a swim ring at (%.0f, %.0f)", a.name, r.position.X, r.position.Z))
				break
			end
		end
	end
	-- Worn rings: on while the effect lasts.
	for _, a in Actors.all() do
		local untilT = a.model:GetAttribute("SwimRingUntil")
		local on = type(untilT) == "number" and now < untilT
		local m = worn[a]
		if on and (not m or not m.Parent) then
			local wm = ringModel("WornSwimRing", 3.4, 0.7)
			local c = wm.PrimaryPart :: BasePart
			c.Anchored = false
			wm:PivotTo(a.root.CFrame * CFrame.new(0, -0.6, 0))
			local w = Instance.new("WeldConstraint")
			w.Part0 = a.root
			w.Part1 = c
			w.Parent = c
			wm.Parent = a.model
			worn[a] = wm
		elseif not on and m then
			m:Destroy()
			worn[a] = nil
		end
	end
end

local function step()
	local now = Actors.now()
	stepDashPads(now)
	stepRings(now)
	local cfg = Config.BurgerBoost
	for _, pad in pads do
		local available = now >= pad.readyAt
		pad.part.Transparency = if available then 0 else 1
		if not available then
			continue
		end
		for _, a in Actors.all() do
			if (Actors.position(a) - pad.position).Magnitude <= Config.BurgerPickupRadius then
				StatusService.apply(a, "boost", cfg.durationSeconds, cfg.speedMultiplier)
				pad.readyAt = now + cfg.respawnSeconds
				break
			end
		end
	end
end

function PickupService.start()
	local folder = Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = Workspace

	for _, pos in MapService.burgerSpawns() do
		local p = Instance.new("Part")
		p.Name = "BurgerBoost"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2, 2, 2)
		p.Color = Color3.fromRGB(150, 90, 40)
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.Position = pos + Vector3.new(0, 2, 0)
		p.Parent = folder
		table.insert(pads, { position = pos + Vector3.new(0, 2, 0), part = p, readyAt = 0 })
	end

	ringFolder = Instance.new("Folder")
	ringFolder.Name = "SwimRings"
	ringFolder.Parent = folder
	local depth = Config.Map.water.depth
	for i, spot in Config.Map.water.swimRing.spots do
		local m = ringModel("SwimRing" .. i, 3, 0.6)
		local pos = Vector3.new(spot.x, depth + 0.4, spot.z)
		m:PivotTo(CFrame.new(pos))
		local light = Instance.new("PointLight")
		light.Color = RING_COLOR
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = m.PrimaryPart
		local sign = Instance.new("BillboardGui")
		sign.Size = UDim2.fromOffset(90, 22)
		sign.StudsOffset = Vector3.new(0, 2.5, 0)
		sign.MaxDistance = 60
		sign.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = RING_COLOR
		label.TextStrokeTransparency = 0.3
		label.Text = "SWIM RING"
		label.Parent = sign
		sign.Parent = m.PrimaryPart
		table.insert(rings, { position = pos, model = m, readyAt = 0 })
	end

	local arena = Workspace:FindFirstChild("Arena")
	if arena then
		for _, d in arena:GetDescendants() do
			if d:IsA("BasePart") and string.match(d.Name, "^DashPad%d+$") then
				table.insert(dashPads, { name = d.Name, position = d.Position })
			end
		end
	end

	task.spawn(function()
		while true do
			step()
			task.wait(TICK)
		end
	end)
end

return PickupService
