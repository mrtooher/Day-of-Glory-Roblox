--!strict
-- Client-side visuals for the 8 character powers. The server only tells us
-- WHAT happened (PlayPowerFx: model, powerId, { action, announcement }); every
-- effect here is built from Config.Powers values (radius, durations) so the
-- picture always matches the real gameplay area. All parts/emitters made here
-- are short-lived and cleaned up with Debris or when their animation ends.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)

local PowerFx = {}

local TAU = math.pi * 2
local GRAVITY = 70
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local rng = Random.new()

-- Helpers ---------------------------------------------------------------------

local fxFolder: Folder? = nil
local function getFolder(): Folder
	if fxFolder and fxFolder.Parent then
		return fxFolder
	end
	local f = Instance.new("Folder")
	f.Name = "PowerFx"
	f.Parent = Workspace
	fxFolder = f
	return f
end

local function ease(a: number): number
	return 1 - (1 - a) ^ 3
end

-- Runs step(alpha) every frame for `duration` seconds (alpha 0..1, last call is
-- exactly 1). Returns a function that stops it early.
local function animate(duration: number, step: (alpha: number) -> ()): (() -> ())
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end
	conn = RunService.Heartbeat:Connect(function()
		local a = math.min(1, (os.clock() - start) / math.max(duration, 0.01))
		local ok, err = pcall(function(): any
			step(a)
			return nil
		end)
		if not ok then
			warn("PowerFx animation error: " .. tostring(err))
			stop()
		elseif a >= 1 then
			stop()
		end
	end)
	return stop
end

-- Pop in with a little overshoot, hold, then (optionally) fade over the last part.
local function popScale(a: number): number
	if a < 0.12 then
		return a / 0.12 * 1.25
	elseif a < 0.22 then
		return 1.25 - (a - 0.12) / 0.1 * 0.25
	end
	return 1
end

local function newPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.one
	p.Parent = getFolder()
	return p
end

-- Invisible part that particle emitters sit on.
local function emitterHost(cf: CFrame, size: Vector3?): Part
	local p = newPart()
	p.Transparency = 1
	p.Size = size or Vector3.one
	p.CFrame = cf
	return p
end

-- Base emitter: Rate 0 and omni-directional, so callers either :Emit(n) a burst
-- or set Rate for a continuous stream.
local function newEmitter(
	parent: Instance,
	c0: Color3,
	c1: Color3,
	size0: number,
	size1: number,
	life0: number,
	life1: number,
	speed0: number,
	speed1: number
): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(c0, c1)
	e.Size = NumberSequence.new(size0, size1)
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new(life0, life1)
	e.Speed = NumberRange.new(speed0, speed1)
	e.Rate = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Parent = parent
	return e
end

-- Where the character's feet are (same formula the server uses for traps).
local function feetOf(model: Model, root: BasePart): Vector3
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hip = if hum then hum.HipHeight else 2
	return root.Position - Vector3.new(0, hip + root.Size.Y / 2, 0)
end

local function flatLook(root: BasePart): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

-- Flat glowing disc lying on the ground.
local function setDisc(p: Part, center: Vector3, diameter: number, thickness: number)
	p.Size = Vector3.new(thickness, math.max(0.1, diameter), math.max(0.1, diameter))
	p.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
end

local function newDisc(center: Vector3, diameter: number, color: Color3, transparency: number): Part
	local p = newPart()
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	setDisc(p, center, diameter, 0.25)
	return p
end

local function newBall(center: Vector3, diameter: number, color: Color3, material: Enum.Material, transparency: number): Part
	local p = newPart()
	p.Shape = Enum.PartType.Ball
	p.Material = material
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.one * math.max(0.1, diameter)
	p.CFrame = CFrame.new(center)
	return p
end

-- A ring of glowing bars that races outward along the ground (an unmistakable
-- "shockwave"). Fades as it grows. Roughly `count` parts, all cleaned up.
local function spawnRing(
	center: Vector3,
	r0: number,
	r1: number,
	duration: number,
	color: Color3,
	count: number,
	thickness: number,
	delaySeconds: number
)
	local function run()
		local bars: { Part } = {}
		for i = 1, count do
			local b = newPart()
			b.Material = Enum.Material.Neon
			b.Color = color
			b.Transparency = 1
			b.Size = Vector3.new(thickness, thickness, 1)
			Debris:AddItem(b, duration + 0.5)
			bars[i] = b
		end
		animate(duration, function(a)
			local r = r0 + (r1 - r0) * ease(a)
			local len = math.max(1, TAU * r / count * 1.2)
			local t = if a < 0.35 then 0.1 else 0.1 + (a - 0.35) / 0.65 * 0.9
			for i, b in bars do
				local th = (i - 1) / count * TAU
				local p = center + Vector3.new(math.cos(th) * r, 0, math.sin(th) * r)
				local tangent = Vector3.new(-math.sin(th), 0, math.cos(th))
				b.CFrame = CFrame.lookAt(p, p + tangent)
				b.Size = Vector3.new(thickness, thickness, len)
				b.Transparency = t
			end
		end)
	end
	if delaySeconds > 0 then
		task.delay(delaySeconds, run)
	else
		run()
	end
end

-- Cartoon word that pops up above a character and floats away. Visible to everyone.
local function floatText(adornee: BasePart, text: string, color: Color3, height: number, lifetime: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatText"
	gui.Size = UDim2.fromOffset(220, 64)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = adornee
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(30, 20, 40)
	label.Parent = holder
	gui.Parent = adornee
	Debris:AddItem(gui, lifetime + 0.3)
	animate(lifetime, function(a)
		scale.Scale = popScale(a)
		gui.StudsOffset = Vector3.new(0, height + a * 2.5, 0)
		local fade = if a > 0.7 then (a - 0.7) / 0.3 else 0
		label.TextTransparency = fade
		label.TextStrokeTransparency = fade
	end)
end

-- White speech bubble with a tail (Yell's "HEY!").
local function speechBubble(adornee: BasePart, text: string, textColor: Color3, lifetime: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShoutBubble"
	gui.Size = UDim2.fromOffset(260, 150)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = adornee
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder

	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromScale(1, 0.68)
	bubble.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bubble.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Color = Color3.fromRGB(30, 20, 40)
	stroke.Parent = bubble
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor
	label.Parent = bubble

	local tail = Instance.new("TextLabel")
	tail.AnchorPoint = Vector2.new(0.5, 0)
	tail.Position = UDim2.fromScale(0.5, 0.62)
	tail.Size = UDim2.fromScale(0.22, 0.36)
	tail.BackgroundTransparency = 1
	tail.Font = Enum.Font.GothamBlack
	tail.TextScaled = true
	tail.Text = "▼"
	tail.TextColor3 = Color3.fromRGB(255, 255, 255)
	tail.TextStrokeTransparency = 0
	tail.TextStrokeColor3 = Color3.fromRGB(30, 20, 40)
	tail.Parent = holder

	gui.Parent = adornee
	Debris:AddItem(gui, lifetime + 0.3)
	animate(lifetime, function(a)
		scale.Scale = if a > 0.8 then popScale(0.5) * (1 - (a - 0.8) / 0.2) else popScale(a)
	end)
end

type Drop = { part: Part, pos: Vector3, vel: Vector3, size: number, landed: boolean }

-- Blobs thrown out of `origin` that fall, then flatten into splats on the ground
-- and fade (tomato sauce, grease, ...). Real parts, so they read at a distance.
local function splatDroplets(
	origin: Vector3,
	groundY: number,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	count: number,
	speed: number,
	minSize: number,
	maxSize: number,
	total: number
)
	local drops: { Drop } = {}
	for _ = 1, count do
		local part = newPart()
		part.Shape = Enum.PartType.Ball
		local s = rng:NextNumber(minSize, maxSize)
		part.Size = Vector3.one * s
		part.Color = color
		part.Material = material
		part.Transparency = transparency
		part.CFrame = CFrame.new(origin)
		Debris:AddItem(part, total + 0.5)
		local th = rng:NextNumber(0, TAU)
		local h = rng:NextNumber(0.3, 1) * speed
		table.insert(drops, {
			part = part,
			pos = origin,
			vel = Vector3.new(math.cos(th) * h, rng:NextNumber(0.5, 1) * speed * 0.9, math.sin(th) * h),
			size = s,
			landed = false,
		})
	end
	local last = 0
	animate(total, function(a)
		local t = a * total
		local dt = t - last
		last = t
		for _, d in drops do
			if not d.landed then
				d.vel += Vector3.new(0, -GRAVITY * dt, 0)
				d.pos += d.vel * dt
				if d.pos.Y <= groundY then
					d.landed = true
					d.part.Shape = Enum.PartType.Cylinder
					local w = d.size * 2.4
					d.part.Size = Vector3.new(0.08, w, w)
					d.part.CFrame = CFrame.new(d.pos.X, groundY + 0.05, d.pos.Z) * CFrame.Angles(0, 0, math.rad(90))
				else
					d.part.CFrame = CFrame.new(d.pos)
				end
			elseif a > 0.65 then
				d.part.Transparency = math.max(transparency, (a - 0.65) / 0.35)
			end
		end
	end)
end

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

-- Activate effects -----------------------------------------------------------

-- YELL: big expanding shockwave sized to the real knockback radius + "HEY!".
local function playYell(model: Model, root: BasePart)
	local R = Config.Powers.Yell.radius
	local feet = feetOf(model, root)
	local ground = feet + Vector3.new(0, 0.3, 0)
	local DURATION = 0.6

	local disc = newDisc(ground, 1, Color3.fromRGB(255, 80, 60), 0.35)
	local shell = newBall(root.Position, 1, Color3.fromRGB(255, 210, 90), Enum.Material.ForceField, 0.3)
	Debris:AddItem(disc, DURATION + 0.4)
	Debris:AddItem(shell, DURATION + 0.4)
	animate(DURATION, function(a)
		local e = ease(a)
		setDisc(disc, ground, R * 2 * e, 0.25)
		disc.Transparency = 0.35 + 0.65 * a
		shell.Size = Vector3.one * math.max(0.1, R * 2 * e)
		shell.Transparency = 0.3 + 0.7 * a
	end)

	spawnRing(ground + Vector3.new(0, 0.4, 0), 1, R, DURATION, Color3.fromRGB(255, 235, 90), 20, 0.8, 0)
	spawnRing(ground + Vector3.new(0, 0.3, 0), 1, R, DURATION, Color3.fromRGB(255, 255, 255), 16, 0.45, 0.12)

	-- Wind/dust blasted outward.
	local host = emitterHost(CFrame.new(ground + Vector3.new(0, 1, 0)))
	local dust = newEmitter(host, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 190, 180), 3, 8, 0.5, 0.9, R * 1.6, R * 2.4)
	dust.Texture = SMOKE_TEXTURE
	dust.Drag = 4
	dust:Emit(28)
	Debris:AddItem(host, 1.5)

	speechBubble(root, "HEY!", Color3.fromRGB(235, 40, 40), 1.1)
end

-- Shared "poof" for Vanish: dark purple smoke, sparkles, a flash shell and a ring.
-- appear = true plays the pop-back-in version (shell collapses inward).
local function vanishPoof(body: Vector3, feet: Vector3, appear: boolean)
	local host = emitterHost(CFrame.new(body))
	local smoke = newEmitter(host, Color3.fromRGB(140, 60, 230), Color3.fromRGB(35, 10, 60), 5, 13, 0.9, 1.5, 8, 16)
	smoke.Texture = SMOKE_TEXTURE
	smoke.Drag = 3
	smoke.Transparency = NumberSequence.new(0.1, 1)
	smoke:Emit(if appear then 26 else 34)

	local sparkles = newEmitter(host, Color3.fromRGB(255, 130, 255), Color3.fromRGB(255, 255, 255), 1.4, 0, 0.6, 1.2, 14, 30)
	sparkles.LightEmission = 1
	sparkles.Acceleration = Vector3.new(0, -14, 0)
	sparkles:Emit(34)

	local stars = newEmitter(host, Color3.fromRGB(255, 240, 120), Color3.fromRGB(180, 80, 255), 0.9, 0, 1, 1.6, 2, 6)
	stars.LightEmission = 1
	stars.Acceleration = Vector3.new(0, 6, 0)
	stars:Emit(14)
	Debris:AddItem(host, 2.5)

	local SIZE = 14
	local shell = newBall(body, 1, Color3.fromRGB(170, 80, 255), Enum.Material.ForceField, 0.2)
	Debris:AddItem(shell, 0.8)
	animate(0.5, function(a)
		local e = ease(a)
		local d = if appear then SIZE * (1 - 0.8 * e) else SIZE * e
		shell.Size = Vector3.one * math.max(0.1, d)
		shell.Transparency = 0.2 + 0.8 * a
	end)
	local ground = feet + Vector3.new(0, 0.3, 0)
	if appear then
		spawnRing(ground, 9, 1, 0.45, Color3.fromRGB(230, 150, 255), 14, 0.5, 0)
	else
		spawnRing(ground, 1, 9, 0.5, Color3.fromRGB(180, 90, 255), 14, 0.6, 0)
	end
end

-- VANISH: poof when he goes, poof when he comes back (enemies never see him in
-- between; Visibility.luau owns the transparency).
local function playVanish(model: Model, root: BasePart)
	vanishPoof(root.Position, feetOf(model, root), false)
	floatText(root, "POOF!", Color3.fromRGB(200, 130, 255), 4, 1.0)

	-- Only the local Vex sees a faint purple shimmer on themselves (no tell for enemies).
	local shimmer: ParticleEmitter? = nil
	if model == Players.LocalPlayer.Character then
		local s = newEmitter(root, Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 255, 255), 0.8, 0, 0.6, 1.0, 1, 4)
		s.LightEmission = 1
		s.Rate = 18
		shimmer = s
	end

	local started = model:GetAttribute("Vanished") == true
	local finished = false
	local conn: RBXScriptConnection? = nil
	local function finish()
		if finished then
			return
		end
		finished = true
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if shimmer then
			shimmer.Enabled = false
			Debris:AddItem(shimmer, 1.5)
		end
		if root.Parent then
			vanishPoof(root.Position, feetOf(model, root), true)
			floatText(root, "BOO!", Color3.fromRGB(255, 220, 90), 4, 0.9)
		end
	end
	-- The server flips the model's Vanished attribute off when it ends (also early,
	-- e.g. when Vex grabs food).
	conn = model:GetAttributeChangedSignal("Vanished"):Connect(function()
		if model:GetAttribute("Vanished") == true then
			started = true
		elseif started then
			finish()
		end
	end)
	-- Safety net if the attribute change was missed.
	task.delay(Config.Powers.Vanish.durationSeconds + 0.6, finish)
end

-- SLOW-MO: blue time-warp dome sized to the real radius, a clock on the ground
-- whose hands spin backwards and wind down, slow drifting particles, and frost on
-- the enemies caught inside.
local function playSlowMo(model: Model, root: BasePart)
	local cfg = Config.Powers.SlowMo
	local R, D = cfg.radius, cfg.durationSeconds
	local center = root.Position
	local ground = feetOf(model, root) + Vector3.new(0, 0.3, 0)
	local BLUE = Color3.fromRGB(70, 160, 255)
	local ICE = Color3.fromRGB(190, 235, 255)

	local dome = newBall(center, 1, BLUE, Enum.Material.ForceField, 0.5)
	local glass = newBall(center, 1, Color3.fromRGB(120, 200, 255), Enum.Material.Glass, 0.88)
	local floor = newDisc(ground - Vector3.new(0, 0.1, 0), R * 2, Color3.fromRGB(50, 130, 255), 0.6)

	local ticks: { Part } = {}
	local pillars: { Part } = {}
	for i = 1, 12 do
		local tick = newPart()
		tick.Material = Enum.Material.Neon
		tick.Color = ICE
		tick.Size = Vector3.new(0.6, 0.4, if i % 3 == 1 then 3.5 else 2)
		table.insert(ticks, tick)
		local pillar = newPart()
		pillar.Material = Enum.Material.Neon
		pillar.Color = BLUE
		pillar.Transparency = 0.45
		pillar.Size = Vector3.new(0.5, 12, 0.5)
		table.insert(pillars, pillar)
	end
	local minuteLen, hourLen = R * 0.9, R * 0.55
	local minuteHand = newPart()
	minuteHand.Material = Enum.Material.Neon
	minuteHand.Color = Color3.fromRGB(255, 255, 255)
	minuteHand.Size = Vector3.new(0.7, 0.5, minuteLen)
	local hourHand = newPart()
	hourHand.Material = Enum.Material.Neon
	hourHand.Color = ICE
	hourHand.Size = Vector3.new(1, 0.5, hourLen)

	-- Slow drifting motes through the whole dome.
	local host = emitterHost(CFrame.new(center), Vector3.one * R * 2)
	local motes = newEmitter(host, Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 255, 255), 0.9, 0.5, 2, 3, 0.3, 1.2)
	motes.Shape = Enum.ParticleEmitterShape.Sphere
	motes.SpreadAngle = Vector2.new(20, 20)
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.25),
		NumberSequenceKeypoint.new(0.75, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.LightEmission = 0.7
	motes.Acceleration = Vector3.new(0, -1.5, 0)
	motes.RotSpeed = NumberRange.new(-20, 20)
	motes.Rate = 28
	task.delay(D, function()
		motes.Enabled = false
	end)

	local all: { Instance } = { dome, glass, floor, minuteHand, hourHand, host }
	for _, t in ticks do
		table.insert(all, t)
	end
	for _, p in pillars do
		table.insert(all, p)
	end
	for _, inst in all do
		Debris:AddItem(inst, D + 2.5)
	end

	spawnRing(ground + Vector3.new(0, 0.4, 0), 1, R, 0.5, ICE, 24, 0.6, 0)

	animate(D, function(a)
		local elapsed = a * D
		local grow = ease(math.min(1, elapsed / 0.35))
		local fadeOut = if elapsed > D - 0.5 then (elapsed - (D - 0.5)) / 0.5 else 0
		local pulse = 1 + 0.025 * math.sin(elapsed * 5)

		dome.Size = Vector3.one * math.max(0.1, R * 2 * grow * pulse)
		dome.Transparency = math.min(1, 0.5 + (1 - grow) * 0.3 + fadeOut * 0.5)
		glass.Size = Vector3.one * math.max(0.1, R * 2 * grow)
		glass.Transparency = math.min(1, 0.88 + fadeOut * 0.12)
		floor.Transparency = math.min(1, 0.6 + fadeOut * 0.4)

		for i, tick in ticks do
			local th = (i - 1) / 12 * TAU
			local r = R * 0.95 * grow
			local p = ground + Vector3.new(math.cos(th) * r, 0, math.sin(th) * r)
			tick.CFrame = CFrame.lookAt(p, ground + Vector3.new(0, 0.0, 0)) -- radial, pointing at the centre
			tick.Transparency = math.min(1, 0.05 + fadeOut)
		end
		for i, pillar in pillars do
			local th = (i - 1) / 12 * TAU
			local r = R * grow
			pillar.CFrame = CFrame.new(ground + Vector3.new(math.cos(th) * r, 6, math.sin(th) * r))
			pillar.Transparency = math.min(1, 0.45 + fadeOut * 0.55)
		end

		-- Hands run backwards and wind down to a stop: time slowing.
		local wind = ease(a)
		local mAngle = -wind * TAU * 2
		local hAngle = -wind * TAU * 0.5
		minuteHand.CFrame = CFrame.new(ground + Vector3.new(0, 0.1, 0))
			* CFrame.Angles(0, mAngle, 0)
			* CFrame.new(0, 0, -minuteLen / 2)
		hourHand.CFrame = CFrame.new(ground + Vector3.new(0, 0.1, 0))
			* CFrame.Angles(0, hAngle, 0)
			* CFrame.new(0, 0, -hourLen / 2)
		minuteHand.Transparency = math.min(1, fadeOut)
		hourHand.Transparency = math.min(1, fadeOut)
	end)

	-- Frost + blue outline on each enemy caught inside (approximation of the
	-- server's check: other team, within radius, not vanished).
	local myTeam = model:GetAttribute("Team")
	for _, m in actorModels() do
		local team = m:GetAttribute("Team")
		local hroot = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			m ~= model
			and hroot
			and team ~= nil
			and team ~= myTeam
			and m:GetAttribute("Vanished") ~= true
			and (hroot.Position - center).Magnitude <= R
		then
			local frost = newEmitter(hroot, Color3.fromRGB(150, 215, 255), Color3.fromRGB(255, 255, 255), 0.9, 0.2, 0.8, 1.3, 1, 3)
			frost.LightEmission = 1
			frost.Acceleration = Vector3.new(0, -5, 0)
			frost.Rate = 22
			local hl = Instance.new("Highlight")
			hl.Name = "SlowHighlight"
			hl.FillColor = BLUE
			hl.FillTransparency = 0.6
			hl.OutlineColor = ICE
			hl.OutlineTransparency = 0.1
			hl.Adornee = m
			hl.Parent = m
			Debris:AddItem(hl, D)
			Debris:AddItem(frost, D + 1.5)
			task.delay(D, function()
				frost.Enabled = false
			end)
			floatText(hroot, "SLOW", Color3.fromRGB(130, 200, 255), 4.5, math.min(D, 1.5))
		end
	end
end

-- SNIFF: speed lines + a dust trail on the dog for the whole sprint, and orange
-- "sniff radar" pulses (matching the orange reveal highlight).
local function playSniff(model: Model, root: BasePart)
	local D = Config.Powers.Sniff.durationSeconds
	local hum = model:FindFirstChildOfClass("Humanoid")
	local feetOffset = (if hum then hum.HipHeight else 2) + root.Size.Y / 2

	local extras: { Instance } = {}

	local feetAtt = Instance.new("Attachment")
	feetAtt.Position = Vector3.new(0, -feetOffset + 0.4, 0.6)
	feetAtt.Parent = root
	table.insert(extras, feetAtt)
	local dust = newEmitter(feetAtt, Color3.fromRGB(215, 190, 150), Color3.fromRGB(190, 170, 140), 1.5, 4, 0.4, 0.8, 2, 6)
	dust.Texture = SMOKE_TEXTURE
	dust.Transparency = NumberSequence.new(0.35, 1)
	dust.SpreadAngle = Vector2.new(40, 40)
	dust.Acceleration = Vector3.new(0, 3, 0)
	dust.Rate = 45
	table.insert(extras, dust)

	local function speedLine(x: number, y: number)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(x, y + 0.3, 0.4)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(x, y - 0.3, 0.4)
		a1.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 120))
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Lifetime = 0.3
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = root
		table.insert(extras, a0)
		table.insert(extras, a1)
		table.insert(extras, trail)
	end
	speedLine(1.7, 1.1)
	speedLine(-1.7, 1.1)
	speedLine(1.4, -0.7)
	speedLine(-1.4, -0.7)

	task.delay(D, function()
		dust.Enabled = false
		for _, inst in extras do
			if inst:IsA("Trail") then
				inst.Enabled = false
			end
			Debris:AddItem(inst, 1)
		end
	end)

	-- Radar pulses from wherever the dog is when each one fires.
	for i = 0, 2 do
		task.delay(i * 1.3, function()
			if root.Parent then
				local ground = feetOf(model, root) + Vector3.new(0, 0.3, 0)
				spawnRing(ground, 1, 16, 0.9, Color3.fromRGB(255, 150, 40), 18, 0.4, 0)
			end
		end)
	end
	floatText(root, "SNIFF SNIFF!", Color3.fromRGB(255, 180, 70), 4, 1.2)
end

-- A short burst where a projectile leaves the caster's hands.
local function muzzleFlash(root: BasePart, color: Color3, secondary: Color3, texture: string?)
	local at = root.Position + flatLook(root) * 3
	local host = emitterHost(CFrame.new(at))
	local e = newEmitter(host, color, secondary, 1.6, 0, 0.25, 0.5, 8, 18)
	e.LightEmission = 1
	if texture then
		e.Texture = texture
		e.LightEmission = 0
	end
	e:Emit(14)
	Debris:AddItem(host, 1)
end

-- GREASE: where the puddle was dropped, show how big it is and splash.
local function playGreaseDrop(model: Model, root: BasePart)
	local feet = feetOf(model, root)
	local ground = feet + Vector3.new(0, 0.3, 0)
	spawnRing(ground, 0.5, Config.Powers.GreaseSpill.radius, 0.4, Color3.fromRGB(255, 210, 80), 14, 0.5, 0)
	splatDroplets(
		ground,
		feet.Y,
		Color3.fromRGB(215, 170, 50),
		Enum.Material.Glass,
		0.15,
		8,
		22,
		0.5,
		0.9,
		1.6
	)
end

local function playActivateFx(model: Model, powerId: string)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	if powerId == "Yell" then
		playYell(model, root)
	elseif powerId == "Vanish" then
		playVanish(model, root)
	elseif powerId == "SlowMo" then
		playSlowMo(model, root)
	elseif powerId == "Sniff" then
		playSniff(model, root)
	elseif powerId == "Fireball" then
		muzzleFlash(root, Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 60, 0), nil)
	elseif powerId == "Whistle" then
		muzzleFlash(root, Color3.fromRGB(255, 245, 100), Color3.fromRGB(120, 210, 255), nil)
		floatText(root, "ZAP!", Color3.fromRGB(255, 240, 90), 4, 0.7)
	elseif powerId == "PizzaToss" then
		muzzleFlash(root, Color3.fromRGB(255, 255, 255), Color3.fromRGB(240, 220, 170), SMOKE_TEXTURE)
	elseif powerId == "GreaseSpill" then
		playGreaseDrop(model, root)
	end
end

-- Hit effects ------------------------------------------------------------------

-- FIREBALL hit: fiery burst + stars orbiting the head for the whole stun.
local function playFireballHit(model: Model, root: BasePart)
	local D = Config.Powers.Fireball.stunSeconds
	local body = root.Position

	local host = emitterHost(CFrame.new(body))
	local fire = newEmitter(host, Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 50, 0), 2.5, 0, 0.4, 0.8, 12, 26)
	fire.LightEmission = 1
	fire:Emit(36)
	local smoke = newEmitter(host, Color3.fromRGB(90, 70, 60), Color3.fromRGB(40, 30, 30), 3, 8, 0.7, 1.2, 4, 10)
	smoke.Texture = SMOKE_TEXTURE
	smoke:Emit(10)
	Debris:AddItem(host, 2)

	local flash = newBall(body, 1, Color3.fromRGB(255, 140, 40), Enum.Material.Neon, 0.2)
	Debris:AddItem(flash, 0.5)
	animate(0.3, function(a)
		flash.Size = Vector3.one * math.max(0.1, 9 * ease(a))
		flash.Transparency = 0.2 + 0.8 * a
	end)

	-- Dizzy stars circling the head.
	local stars: { BillboardGui } = {}
	for _ = 1, 3 do
		local gui = Instance.new("BillboardGui")
		gui.Name = "StunStars"
		gui.Size = UDim2.fromOffset(46, 46)
		gui.AlwaysOnTop = true
		gui.Adornee = root
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = "★"
		label.TextColor3 = Color3.fromRGB(255, 210, 40)
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(180, 80, 0)
		label.Parent = gui
		gui.Parent = root
		Debris:AddItem(gui, D + 0.3)
		table.insert(stars, gui)
	end
	animate(D, function(a)
		for i, gui in stars do
			local th = a * D * 7 + (i - 1) / #stars * TAU
			gui.StudsOffset = Vector3.new(math.cos(th) * 2.2, 3.6 + 0.25 * math.sin(th * 2), math.sin(th) * 2.2)
		end
	end)
	floatText(root, "OUCH!", Color3.fromRGB(255, 150, 50), 5.5, 1.0)
end

-- STUN GUN hit: yellow/blue sparks, a flickering outline, a point light and a
-- cage of zig-zag lightning around the target for the whole freeze.
local function playStunGunHit(model: Model, root: BasePart)
	local D = Config.Powers.Whistle.freezeSeconds
	local YELLOW = Color3.fromRGB(255, 240, 80)
	local CYAN = Color3.fromRGB(130, 220, 255)

	local flash = newBall(root.Position, 1, Color3.fromRGB(255, 255, 200), Enum.Material.Neon, 0.2)
	Debris:AddItem(flash, 0.4)
	animate(0.25, function(a)
		flash.Size = Vector3.one * math.max(0.1, 10 * ease(a))
		flash.Transparency = 0.2 + 0.8 * a
	end)

	local sparks = newEmitter(root, YELLOW, CYAN, 0.7, 0, 0.25, 0.5, 6, 14)
	sparks.LightEmission = 1
	sparks.Rate = 70
	sparks:Emit(30)
	local light = Instance.new("PointLight")
	light.Color = YELLOW
	light.Range = 14
	light.Brightness = 3
	light.Parent = root
	local hl = Instance.new("Highlight")
	hl.Name = "StunHighlight"
	hl.FillColor = YELLOW
	hl.FillTransparency = 0.5
	hl.OutlineColor = CYAN
	hl.OutlineTransparency = 0
	hl.Adornee = model
	hl.Parent = model
	Debris:AddItem(sparks, D + 0.8)
	Debris:AddItem(light, D)
	Debris:AddItem(hl, D)
	task.delay(D, function()
		sparks.Enabled = false
	end)

	-- 3 bolts x 6 zig-zag segments, re-rolled ~15x a second.
	local BOLTS, SEGMENTS = 3, 6
	local segs: { Part } = {}
	for _ = 1, BOLTS * SEGMENTS do
		local s = newPart()
		s.Material = Enum.Material.Neon
		s.Color = YELLOW
		s.Size = Vector3.new(0.22, 0.22, 1)
		Debris:AddItem(s, D + 0.4)
		table.insert(segs, s)
	end
	local lastRoll = -1
	animate(D, function(a)
		local now = os.clock()
		if now - lastRoll < 0.065 or not root.Parent then
			return
		end
		lastRoll = now
		hl.FillColor = if hl.FillColor == YELLOW then CYAN else YELLOW
		local base = root.Position
		local fadeOut = a > 0.9
		for b = 1, BOLTS do
			local ang = rng:NextNumber(0, TAU)
			local bx, bz = math.cos(ang) * 2.3, math.sin(ang) * 2.3
			local visible = not fadeOut and rng:NextNumber() > 0.2
			local prev = base + Vector3.new(bx, 3.3, bz)
			for k = 1, SEGMENTS do
				local y = 3.3 - k * (6.6 / SEGMENTS)
				local jitter = if k == SEGMENTS then 0 else 1
				local nxt = base
					+ Vector3.new(bx + rng:NextNumber(-0.9, 0.9) * jitter, y, bz + rng:NextNumber(-0.9, 0.9) * jitter)
				local len = (nxt - prev).Magnitude
				local seg = segs[(b - 1) * SEGMENTS + k]
				seg.Size = Vector3.new(0.22, 0.22, len + 0.1)
				seg.CFrame = CFrame.lookAt(prev, nxt) * CFrame.new(0, 0, -len / 2)
				seg.Color = if (k + b) % 2 == 0 then YELLOW else CYAN
				seg.Transparency = if visible then 0 else 1
				prev = nxt
			end
		end
	end)
	floatText(root, "ZZZAP!", Color3.fromRGB(255, 240, 90), 5.2, 1.0)
end

-- PIZZA hit: sauce splashes everywhere, a sauce splat sticks to the target (and
-- drips) for as long as they're slowed.
local function playPizzaHit(model: Model, root: BasePart)
	local D = Config.Powers.PizzaToss.slowSeconds
	local RED = Color3.fromRGB(205, 40, 25)
	local feet = feetOf(model, root)

	local host = emitterHost(CFrame.new(root.Position))
	local puff = newEmitter(host, Color3.fromRGB(230, 60, 40), Color3.fromRGB(150, 20, 15), 1.5, 3.5, 0.5, 0.9, 10, 22)
	puff.Texture = SMOKE_TEXTURE
	puff.Transparency = NumberSequence.new(0.1, 1)
	puff.Acceleration = Vector3.new(0, -20, 0)
	puff:Emit(26)
	local cheese = newEmitter(host, Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 180, 40), 0.9, 0.3, 0.6, 1, 8, 18)
	cheese.Acceleration = Vector3.new(0, -35, 0)
	cheese:Emit(12)
	Debris:AddItem(host, 1.8)

	splatDroplets(root.Position, feet.Y, RED, Enum.Material.SmoothPlastic, 0, 9, 24, 0.5, 1.0, 2.2)

	-- Sauce splat on the target.
	local gui = Instance.new("BillboardGui")
	gui.Name = "SauceSplat"
	gui.Size = UDim2.fromScale(4.5, 4.5)
	gui.StudsOffset = Vector3.new(0, 0.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = root
	local blobs: { Frame } = {}
	local function blob(x: number, y: number, size: number, color: Color3)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(size, size)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = gui
		table.insert(blobs, f)
	end
	blob(0.5, 0.5, 0.55, RED)
	for i = 1, 7 do
		local th = (i - 1) / 7 * TAU + rng:NextNumber(-0.3, 0.3)
		local dist = rng:NextNumber(0.28, 0.4)
		blob(0.5 + math.cos(th) * dist, 0.5 + math.sin(th) * dist, rng:NextNumber(0.12, 0.24), RED)
	end
	blob(0.45, 0.45, 0.14, Color3.fromRGB(150, 28, 28)) -- pepperoni bit
	blob(0.58, 0.56, 0.1, Color3.fromRGB(255, 215, 80)) -- cheese bit
	gui.Parent = root
	Debris:AddItem(gui, D + 0.3)

	local drip = newEmitter(root, RED, Color3.fromRGB(150, 25, 20), 0.5, 0.3, 0.5, 0.8, 0, 1)
	drip.Texture = SMOKE_TEXTURE
	drip.Transparency = NumberSequence.new(0, 0.8)
	drip.Acceleration = Vector3.new(0, -30, 0)
	drip.Rate = 14
	Debris:AddItem(drip, D + 1)
	task.delay(D, function()
		drip.Enabled = false
	end)

	animate(D, function(a)
		local t = if a > 0.8 then (a - 0.8) / 0.2 else 0
		for _, f in blobs do
			f.BackgroundTransparency = t
		end
	end)
	floatText(root, "SLOWED!", Color3.fromRGB(255, 120, 60), 5, 1.1)
end

-- GREASE trap entered: goopy splash + droplets, then slippery drips while slowed.
local function playGreaseEnter(model: Model, root: BasePart)
	local D = Config.Powers.GreaseSpill.slowSeconds
	local feet = feetOf(model, root)
	local at = feet + Vector3.new(0, 0.6, 0)
	local GOLD = Color3.fromRGB(235, 195, 70)
	local BROWN = Color3.fromRGB(150, 105, 35)

	local host = emitterHost(CFrame.new(at))
	local splash = newEmitter(host, GOLD, BROWN, 1.5, 3, 0.5, 0.9, 8, 18)
	splash.Texture = SMOKE_TEXTURE
	splash.Transparency = NumberSequence.new(0.2, 1)
	splash.Acceleration = Vector3.new(0, -25, 0)
	splash.SpreadAngle = Vector2.new(60, 60)
	splash:Emit(24)
	local bubbles = newEmitter(host, Color3.fromRGB(255, 245, 160), Color3.fromRGB(255, 255, 220), 0.7, 1.4, 0.8, 1.4, 3, 8)
	bubbles.Texture = SMOKE_TEXTURE
	bubbles.Transparency = NumberSequence.new(0.45, 1)
	bubbles.Acceleration = Vector3.new(0, 7, 0)
	bubbles:Emit(14)
	Debris:AddItem(host, 2)

	splatDroplets(at, feet.Y, Color3.fromRGB(215, 170, 50), Enum.Material.Glass, 0.15, 8, 20, 0.4, 0.8, 1.8)

	local drip = newEmitter(root, GOLD, BROWN, 0.5, 0.3, 0.5, 0.8, 0, 1)
	drip.Texture = SMOKE_TEXTURE
	drip.Transparency = NumberSequence.new(0.2, 0.9)
	drip.Acceleration = Vector3.new(0, -25, 0)
	drip.Rate = 12
	Debris:AddItem(drip, D + 1)
	task.delay(D, function()
		drip.Enabled = false
	end)
	floatText(root, "SLIP!", Color3.fromRGB(255, 220, 90), 5, 1.0)
end

local function playHitFx(model: Model, powerId: string, announcement: string?)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	if powerId == "Fireball" then
		playFireballHit(model, root)
	elseif powerId == "Whistle" then
		playStunGunHit(model, root)
	elseif powerId == "PizzaToss" then
		playPizzaHit(model, root)
	elseif powerId == "GreaseSpill" then
		playGreaseEnter(model, root)
	end

	if announcement then
		createBigText(announcement, model)
	end
end

function PowerFx.start()
	local remotes = ReplicatedStorage:WaitForChild(Net.RemotesFolder)
	local playFx = remotes:WaitForChild(Net.PlayPowerFx) :: RemoteEvent

	playFx.OnClientEvent:Connect(function(model: Model, powerId: string, data: any)
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			return
		end
		local action = if type(data) == "table" and data.action then data.action else "activate"
		-- One broken effect must never stop the others (or the big text).
		local ok, err = pcall(function()
			if action == "activate" then
				playActivateFx(model, powerId)
				if type(data) == "table" and data.announcement then
					createBigText(data.announcement, model)
				end
			elseif action == "hit" or action == "trap_enter" then
				playHitFx(model, powerId, if type(data) == "table" then data.announcement else nil)
			end
		end)
		if not ok then
			warn("PowerFx " .. tostring(powerId) .. " " .. tostring(action) .. " failed: " .. tostring(err))
		end
	end)
end

return PowerFx
