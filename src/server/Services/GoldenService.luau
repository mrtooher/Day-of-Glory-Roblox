--!strict
-- Golden Burger (Jim 2026-11-05): once a match, 3 minutes in, a golden burger
-- appears on the bridge. Anyone can grab it; carried to your own drop-off it
-- scores Config.GoldenBurger.points. Its carrier can be tagged anywhere
-- (TagService asks isCarrier). Rules live in Shared/Rules/GoldenBurger.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GoldenBurger = require(ReplicatedStorage.Shared.Rules.GoldenBurger)
local Remotes = require(script.Parent.Remotes)
local MapService = require(script.Parent.MapService)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

local GoldenService = {}

local MatchService: any, StatusService: any
local state: GoldenBurger.State = GoldenBurger.new()
local folder: Folder
local part: BasePart
local weld: WeldConstraint?
local spot: Vector3 = Vector3.new(0, 3, 0)

local TICK = 0.1
local GOLD = Color3.fromRGB(255, 200, 40)
local CYL = CFrame.Angles(0, 0, math.rad(90))

local function piece(name: string, size: Vector3, color: Color3, shape: Enum.PartType, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return p
end

-- A burger in gold: root is the bottom bun (a flat disc), the rest welded on.
local function buildGolden(): BasePart
	local root = piece("GoldenBurger", Vector3.new(0.8, 3.2, 3.2), GOLD, Enum.PartType.Cylinder, Enum.Material.Foil)
	root.Anchored = true
	local inv = CYL:Inverse()
	type Bit = { name: string, size: Vector3, color: Color3, shape: Enum.PartType, offset: CFrame }
	local bits: { Bit } = {
		{ name = "Patty", size = Vector3.new(0.6, 3.3, 3.3), color = Color3.fromRGB(200, 130, 20), shape = Enum.PartType.Cylinder, offset = CFrame.new(0, 0.7, 0) * CYL },
		{ name = "Cheese", size = Vector3.new(0.15, 3.6, 3.6), color = Color3.fromRGB(255, 235, 120), shape = Enum.PartType.Cylinder, offset = CFrame.new(0, 1.05, 0) * CYL },
		{ name = "TopBun", size = Vector3.new(1.8, 3.3, 3.3), color = GOLD, shape = Enum.PartType.Ball, offset = CFrame.new(0, 1.7, 0) },
	}
	for _, b in bits do
		local p = piece(b.name, b.size, b.color, b.shape, Enum.Material.Foil)
		local w = Instance.new("Weld")
		w.Part0 = root
		w.Part1 = p
		w.C0 = inv * b.offset
		w.Parent = p
		p.Parent = root
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Brightness = 2
	light.Range = 16
	light.Parent = root
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = GOLD
	sparkles.Parent = root
	local sign = Instance.new("BillboardGui")
	sign.Name = "GoldenSign"
	sign.Size = UDim2.fromOffset(150, 34)
	sign.StudsOffset = Vector3.new(0, 4, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 600
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(60, 40, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = string.format("GOLDEN BURGER +%d", Config.GoldenBurger.points)
	label.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	sign.Parent = root
	return root
end

local function settings(): GoldenBurger.Settings
	return {
		appearAfterSeconds = Config.GoldenBurger.appearAfterSeconds,
		points = Config.GoldenBurger.points,
		droppedSeconds = Config.GoldenBurger.droppedSeconds,
	}
end

local function detach()
	if weld then
		weld:Destroy()
		weld = nil
	end
	part.Anchored = true
end

local function setCarrierFlag(actor: Actor?, on: boolean)
	if actor then
		actor.model:SetAttribute("GoldenCarrier", on)
		Actors.setCarrying(actor, on)
	end
end

local function carrier(): Actor?
	return if state.status == "Carried" and state.carrier then Actors.get(state.carrier) else nil
end

local function hide()
	detach()
	part.Parent = nil
end

local function showAt(pos: Vector3)
	detach()
	part.CFrame = CFrame.new(pos) * CYL
	part.Parent = folder
end

local function attach(actor: Actor)
	detach()
	part.Anchored = false
	part.CFrame = actor.root.CFrame * CFrame.new(0, 4, 0) * CYL
	local w = Instance.new("WeldConstraint")
	w.Part0 = actor.root
	w.Part1 = part
	w.Parent = part
	weld = w
	part.Parent = folder
	setCarrierFlag(actor, true)
	StatusService.cancelVanish(actor)
end

local function dropAt(at: Vector3)
	local c = carrier()
	state = GoldenBurger.drop(state, Actors.now())
	setCarrierFlag(c, false)
	showAt(Vector3.new(at.X, math.max(1.5, at.Y - 1.5), at.Z))
end

function GoldenService.init(services)
	MatchService, StatusService = services.MatchService, services.StatusService
end

-- True while `actor` carries the golden burger (TagService: taggable anywhere).
function GoldenService.isCarrier(actor: Actor): boolean
	return state.status == "Carried" and state.carrier == actor.id
end

-- Where to go grab it (bots), or nil when it isn't lying around.
function GoldenService.targetPosition(): Vector3?
	if state.status == "OnBridge" or state.status == "Dropped" then
		return part.Position
	end
	return nil
end

-- Called with FoodService.dropCarried (tagged, yelled, left, died).
function GoldenService.dropCarried(actor: Actor)
	if GoldenService.isCarrier(actor) then
		dropAt(actor.root.Position)
	end
end

-- New match (or match over): back to waiting, off the map.
function GoldenService.reset()
	setCarrierFlag(carrier(), false)
	state = GoldenBurger.new()
	hide()
end

local function step()
	if not MatchService.isPlaying() then
		if state.status ~= "Waiting" then
			GoldenService.reset()
		end
		return
	end
	local now = Actors.now()
	local cfg = settings()
	local ev
	state, ev = GoldenBurger.tick(state, MatchService.elapsed(), now, cfg)
	if ev == "Appeared" or ev == "Returned" then
		spot = MapService.bridgeSpot()
		showAt(spot)
		Remotes.announce(if ev == "Appeared"
			then string.format("GOLDEN BURGER on the bridge! Worth %d points!", cfg.points)
			else "The golden burger is back on the bridge!")
		print("[Golden] " .. ev .. " at " .. tostring(spot))
	end

	if state.status == "OnBridge" or state.status == "Dropped" then
		for _, a in Actors.all() do
			if a.humanoid.Health > 0 and (Actors.position(a) - part.Position).Magnitude <= Config.GoldenBurger.pickupRadius then
				local nextState, err = GoldenBurger.pickUp(state, { id = a.id, team = a.team, carrying = a.carrying })
				if not err then
					state = nextState
					attach(a)
					local msg = string.format("%s grabbed the GOLDEN BURGER for %s!", a.name, Config.teamName(a.team))
					print("[Golden] " .. msg)
					Remotes.announce(msg)
					break
				end
			end
		end
	elseif state.status == "Carried" then
		local c = carrier()
		if not c or c.humanoid.Health <= 0 then
			dropAt(part.Position)
		else
			local dropoff = MapService.kitchen(c.team).dropoff
			local flat = Vector3.new(dropoff.X, c.root.Position.Y, dropoff.Z)
			if (c.root.Position - flat).Magnitude <= Config.DropoffRadius then
				local points
				state, points = GoldenBurger.score(state, c.team, cfg)
				if points then
					setCarrierFlag(c, false)
					hide()
					print("[Golden] scored by " .. c.name .. " for " .. c.team)
					MatchService.awardPoint(c.team, c, points)
				end
			end
		end
	end
end

function GoldenService.start()
	folder = Instance.new("Folder")
	folder.Name = "GoldenBurger"
	folder.Parent = Workspace
	part = buildGolden()
	task.spawn(function()
		while true do
			xpcall(step, function(err)
				warn("GoldenService: " .. tostring(err))
			end)
			task.wait(TICK)
		end
	end)
end

return GoldenService
