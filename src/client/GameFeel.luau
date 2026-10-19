--!strict
-- Feedback that makes the loop readable and fun (client-only visuals):
--   * floating markers over both kitchens: "RAID HERE" on the enemy counter,
--     "DEFEND" on yours (seen through walls, with distance)
--   * while you carry food: a glowing guide beam from you to your drop-off,
--     a light pillar on the drop-off and "GOT IT! RUN HOME!"
--   * when anyone scores: confetti on that drop-off and a big banner
--   * a how-to hint for the first seconds of each match

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local GameFeel = {}

local HINT_SECONDS = 20

local function teamColor(teamId: string): Color3
	for _, t in Config.Teams do
		if t.id == teamId then
			return BrickColor.new(t.color :: any).Color
		end
	end
	return Color3.new(1, 1, 1)
end

local function bigText(gui: ScreenGui, text: string, color: Color3, seconds: number)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.8, 0.12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(seconds, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(label, 0.5)
	end)
end

local function confetti(at: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = at + Vector3.new(0, 2, 0)
	anchor.Parent = Workspace
	local colors = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(80, 200, 255),
		Color3.fromRGB(120, 230, 100),
		Color3.fromRGB(230, 120, 255),
	}
	for _, c in colors do
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(c)
		e.Size = NumberSequence.new(0.5)
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Speed = NumberRange.new(25, 45)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, -35, 0)
		e.RotSpeed = NumberRange.new(-300, 300)
		e.Rotation = NumberRange.new(0, 360)
		e.EmissionDirection = Enum.NormalId.Top
		e.Enabled = false
		e.Parent = anchor
		e:Emit(30)
	end
	Debris:AddItem(anchor, 3)
end

-- Floating marker above a kitchen counter, visible through walls.
local function kitchenMarker(adornee: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "KitchenMarker"
	gui.Size = UDim2.fromOffset(200, 56)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	return gui, label
end

function GameFeel.start()
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild(Net.MatchStateFolder)
	local arena = Workspace:WaitForChild("Arena", 30)
	if not arena then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GameFeel"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -90)
	hint.Size = UDim2.fromOffset(520, 34)
	hint.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	hint.BackgroundTransparency = 0.3
	hint.Font = Enum.Font.GothamBold
	hint.TextScaled = true
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.Visible = false
	hint.Parent = gui
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 8)
	hintCorner.Parent = hint
	local hintLimit = Instance.new("UISizeConstraint")
	hintLimit.MaxSize = Vector2.new(520, 34)
	hintLimit.Parent = hint
	hint.Size = UDim2.new(0.9, 0, 0, 34)

	-- Kitchen markers and drop-off attachments.
	type Kitchen = { pantry: BasePart?, dropoff: BasePart?, marker: BillboardGui?, label: TextLabel?, attach: Attachment? }
	local kitchens: { [string]: Kitchen } = {}
	for _, t in Config.Teams do
		local pantry = arena:FindFirstChild(t.id .. "Pantry", true) :: BasePart?
		local dropoff = arena:FindFirstChild(t.id .. "Dropoff", true) :: BasePart?
		local k: Kitchen = { pantry = pantry, dropoff = dropoff }
		if pantry then
			local marker, label = kitchenMarker(pantry)
			marker.Parent = gui
			k.marker = marker
			k.label = label
		end
		if dropoff then
			local a = Instance.new("Attachment")
			a.Name = "GuideTarget"
			a.Position = Vector3.new(0, 3, 0)
			a.Parent = dropoff
			k.attach = a
		end
		kitchens[t.id] = k
	end

	-- Guide beam + pillar (shown only while carrying).
	local beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.FaceCamera = true
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.2)
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.Segments = 20
	beam.CurveSize0 = 0
	beam.Enabled = false
	beam.Parent = Workspace

	local pillar = Instance.new("Part")
	pillar.Name = "DropoffPillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.Material = Enum.Material.Neon
	pillar.Transparency = 1
	pillar.Size = Vector3.new(60, 10, 10)
	pillar.Parent = Workspace

	local lastScores: { [string]: number } = {}
	for _, t in Config.Teams do
		local key = "Score_" .. t.id
		lastScores[t.id] = state:GetAttribute(key) or 0
		state:GetAttributeChangedSignal(key):Connect(function()
			local v = state:GetAttribute(key) or 0
			if v > lastScores[t.id] then
				local k = kitchens[t.id]
				if k and k.dropoff then
					confetti(k.dropoff.Position)
				end
				local mine = player.Team ~= nil and player.Team.Name == t.id
				bigText(gui, if mine then "+1  NICE DELIVERY!" else string.upper(t.id) .. " SCORED!", teamColor(t.id), 1.6)
			end
			lastScores[t.id] = v
		end)
	end

	local wasCarrying = false
	local hintUntil = 0
	local lastPhase = state:GetAttribute("Phase")
	local rootAttach: Attachment? = nil

	while true do
		local now = Workspace:GetServerTimeNow()
		local phase = state:GetAttribute("Phase")
		if phase ~= lastPhase then
			if phase == "Playing" then
				hintUntil = now + HINT_SECONDS
			end
			lastPhase = phase
		end
		local playing = phase == "Playing"
		local myTeam = if player.Team then player.Team.Name else nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

		-- Kitchen markers: which one is "RAID", with distance.
		for teamId, k in kitchens do
			local label = k.label
			if label and k.pantry then
				local dist = if root then math.floor((root.Position - k.pantry.Position).Magnitude) else 0
				if myTeam == nil then
					label.Text = string.upper(teamId) .. " KITCHEN"
					label.TextColor3 = teamColor(teamId)
				elseif teamId == myTeam then
					label.Text = string.format("DEFEND  %dm", dist)
					label.TextColor3 = teamColor(teamId)
				else
					label.Text = string.format("RAID HERE!  %dm", dist)
					label.TextColor3 = Color3.fromRGB(255, 220, 60)
				end
				-- Your own marker only shows when you're away from home.
				if k.marker then
					k.marker.Enabled = not (teamId == myTeam and dist < 40)
				end
			end
		end

		-- Carrying: beam to your drop-off + pillar + "RUN HOME".
		local carrying = character ~= nil and character:GetAttribute("Carrying") == true
		local home = if myTeam then kitchens[myTeam] else nil
		if carrying and root and home and home.attach and home.dropoff then
			local existing = rootAttach
			local source: Attachment
			if existing and existing.Parent == root then
				source = existing
			else
				source = Instance.new("Attachment")
				source.Name = "GuideSource"
				source.Parent = root
				rootAttach = source
			end
			beam.Attachment0 = source
			beam.Attachment1 = home.attach
			beam.Color = ColorSequence.new(teamColor(myTeam :: string), Color3.fromRGB(255, 240, 120))
			beam.Enabled = true
			pillar.Color = teamColor(myTeam :: string)
			pillar.CFrame = CFrame.new(home.dropoff.Position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
			pillar.Transparency = 0.6 + 0.15 * math.sin(now * 6)
		else
			beam.Enabled = false
			pillar.Transparency = 1
		end
		if carrying and not wasCarrying then
			bigText(gui, "GOT IT!  RUN HOME!", Color3.fromRGB(255, 230, 80), 1.4)
		end
		wasCarrying = carrying

		-- How-to hint at the start of each match.
		if playing and now < hintUntil and not carrying then
			hint.Visible = true
			hint.Text = "Run to the RAID HERE marker, walk up to their counter to grab food, bring it home!"
		elseif carrying then
			hint.Visible = true
			hint.Text = "Follow the beam to your glowing drop-off!  Don't get tagged!"
		else
			hint.Visible = false
		end

		task.wait(0.1)
	end
end

return GameFeel
