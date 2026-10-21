--!strict
-- Food pieces in the world: pantry restocking, pickup, carrying, dropping
-- and scoring. All decisions go through the pure FoodState rules; this file
-- only measures server-side distances and moves Parts.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FoodState = require(ReplicatedStorage.Shared.Rules.FoodState)
local Reach = require(ReplicatedStorage.Shared.Rules.Reach)
local FoodLayout = require(ReplicatedStorage.Shared.Rules.FoodLayout)
local Remotes = require(script.Parent.Remotes)
local MapService = require(script.Parent.MapService)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

type Item = {
	food: FoodState.Food,
	part: BasePart,
	rot: CFrame, -- the food root's resting orientation
	slot: Vector3,
	onRoof: boolean, -- sits on a rooftop pedestal (not the base counter)
	weld: WeldConstraint?,
}

local FoodService = {}

local MatchService: any, StatusService: any
local items: { Item } = {}
local folder: Folder

local TICK = 0.1
local settings = {
	droppedSeconds = Config.DroppedFoodSeconds,
	restockSeconds = Config.PantryRestockSeconds,
}

-- Food models: a root Part (what gets moved/welded) plus welded detail parts
-- so each piece reads as pizza / burger / taco / sushi at a glance.
type Piece = { size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material? }

local CYL = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y (flat disc)

local looks: { [string]: { root: Piece, details: { Piece } } } = {
	Pizza = {
		root = { size = Vector3.new(0.4, 2.6, 2.6), offset = CYL, color = Color3.fromRGB(214, 150, 70), shape = Enum.PartType.Cylinder },
		details = {
			{ size = Vector3.new(0.15, 2.2, 2.2), offset = CFrame.new(0, 0.22, 0) * CYL, color = Color3.fromRGB(255, 205, 70), shape = Enum.PartType.Cylinder },
			{ size = Vector3.new(0.12, 0.6, 0.6), offset = CFrame.new(0.5, 0.32, 0.3) * CYL, color = Color3.fromRGB(190, 40, 35), shape = Enum.PartType.Cylinder },
			{ size = Vector3.new(0.12, 0.6, 0.6), offset = CFrame.new(-0.45, 0.32, 0.4) * CYL, color = Color3.fromRGB(190, 40, 35), shape = Enum.PartType.Cylinder },
			{ size = Vector3.new(0.12, 0.6, 0.6), offset = CFrame.new(0.05, 0.32, -0.55) * CYL, color = Color3.fromRGB(190, 40, 35), shape = Enum.PartType.Cylinder },
		},
	},
	Burger = {
		root = { size = Vector3.new(0.6, 2.2, 2.2), offset = CYL, color = Color3.fromRGB(205, 140, 60), shape = Enum.PartType.Cylinder },
		details = {
			{ size = Vector3.new(0.45, 2.3, 2.3), offset = CFrame.new(0, 0.5, 0) * CYL, color = Color3.fromRGB(110, 60, 30), shape = Enum.PartType.Cylinder },
			{ size = Vector3.new(0.1, 2.5, 2.5), offset = CFrame.new(0, 0.78, 0) * CYL, color = Color3.fromRGB(255, 200, 40), shape = Enum.PartType.Cylinder },
			{ size = Vector3.new(0.1, 2.6, 2.6), offset = CFrame.new(0, 0.88, 0) * CYL, color = Color3.fromRGB(90, 190, 70), shape = Enum.PartType.Cylinder },
			{ size = Vector3.new(1.2, 2.3, 2.3), offset = CFrame.new(0, 1.3, 0), color = Color3.fromRGB(220, 150, 65), shape = Enum.PartType.Ball },
		},
	},
	Taco = {
		root = { size = Vector3.new(2.4, 0.3, 1.0), offset = CFrame.new(), color = Color3.fromRGB(240, 200, 80) },
		details = {
			{ size = Vector3.new(2.4, 1.3, 0.25), offset = CFrame.new(0, 0.6, 0.45) * CFrame.Angles(math.rad(-20), 0, 0), color = Color3.fromRGB(240, 200, 80) },
			{ size = Vector3.new(2.4, 1.3, 0.25), offset = CFrame.new(0, 0.6, -0.45) * CFrame.Angles(math.rad(20), 0, 0), color = Color3.fromRGB(240, 200, 80) },
			{ size = Vector3.new(2.2, 0.4, 0.7), offset = CFrame.new(0, 0.55, 0), color = Color3.fromRGB(130, 70, 40) },
			{ size = Vector3.new(2.2, 0.25, 0.8), offset = CFrame.new(0, 0.85, 0), color = Color3.fromRGB(100, 200, 80) },
			{ size = Vector3.new(0.35, 0.3, 0.35), offset = CFrame.new(0.6, 1.05, 0), color = Color3.fromRGB(220, 50, 40) },
			{ size = Vector3.new(0.35, 0.3, 0.35), offset = CFrame.new(-0.5, 1.05, 0.1), color = Color3.fromRGB(220, 50, 40) },
		},
	},
	Sushi = {
		root = { size = Vector3.new(1.8, 0.8, 1.0), offset = CFrame.new(), color = Color3.fromRGB(250, 250, 245) },
		details = {
			{ size = Vector3.new(2.0, 0.3, 1.1), offset = CFrame.new(0, 0.5, 0), color = Color3.fromRGB(255, 140, 90) },
			{ size = Vector3.new(0.35, 1.0, 1.15), offset = CFrame.new(0, 0.25, 0), color = Color3.fromRGB(30, 50, 35) },
		},
	},
}

local function makePiece(spec: Piece, name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = spec.size
	p.Color = spec.color
	p.Shape = spec.shape or Enum.PartType.Block
	p.Material = spec.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return p
end

-- Detail parts hang off the root with explicit Weld offsets (C0), so they
-- follow it wherever it is moved, whether or not it is in Workspace yet.
-- Offsets in `looks` are relative to the food's upright frame; the root's own
-- rotation (look.root.offset, e.g. a flat disc) is applied on every move.
local function buildFood(foodType: string): Part
	local look = looks[foodType]
	local root = makePiece(look.root, foodType)
	root.Anchored = true
	local rootInv = look.root.offset:Inverse()
	for i, d in look.details do
		local part = makePiece(d, foodType .. "Bit" .. i)
		part.Anchored = false
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = rootInv * d.offset
		weld.Parent = part
		part.Parent = root
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 220, 150)
	glow.Brightness = 1.5
	glow.Range = 8
	glow.Parent = root
	return root
end

function FoodService.init(services)
	MatchService, StatusService = services.MatchService, services.StatusService
end

local function detach(item: Item)
	if item.weld then
		item.weld:Destroy()
		item.weld = nil
	end
	item.part.Anchored = true
end

local function showInPantry(item: Item)
	detach(item)
	item.part.CFrame = CFrame.new(item.slot) * item.rot
	item.part.Parent = folder
end

local function showDropped(item: Item, at: Vector3)
	detach(item)
	-- Drop at the carrier's feet, not always at ground level: a carrier tagged
	-- on a rooftop (jump pads) would otherwise drop it inside the building.
	item.part.CFrame = CFrame.new(Vector3.new(at.X, math.max(1, at.Y - 2), at.Z)) * item.rot
	item.part.Parent = folder
end

local function hide(item: Item)
	detach(item)
	item.part.Parent = nil
end

local function attach(item: Item, actor: Actor)
	detach(item)
	local p = item.part
	p.Anchored = false
	p.CFrame = actor.root.CFrame * CFrame.new(0, 3.8, 0) * item.rot
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = actor.root
	weld.Part1 = p
	weld.Parent = p
	item.weld = weld
	p.Parent = folder
	Actors.setCarrying(actor, true)
	-- Carrying food cancels Vex's vanish.
	StatusService.cancelVanish(actor)
end

local function carrierOf(item: Item): Actor?
	local id = item.food.carrier
	return if id then Actors.get(id) else nil
end

local function actorsNear(pos: Vector3, radius: number): { Actor }
	local list = {}
	for _, a in Actors.all() do
		if (Actors.position(a) - pos).Magnitude <= radius then
			table.insert(list, a)
		end
	end
	return list
end

local function actorInput(actor: Actor): FoodState.Actor
	return { id = actor.id, team = actor.team, carrying = actor.carrying }
end

function FoodService.resetAll()
	for _, item in items do
		local carrier = carrierOf(item)
		if carrier then
			Actors.setCarrying(carrier, false)
		end
		item.food = FoodState.new(item.food.owner, item.food.foodType)
		showInPantry(item)
	end
end

-- Called when an actor is tagged, yelled at, leaves, or dies.
function FoodService.dropCarried(actor: Actor)
	for _, item in items do
		if item.food.status == "Carried" and item.food.carrier == actor.id then
			item.food = FoodState.drop(item.food, Actors.now())
			showDropped(item, actor.root.Position)
		end
	end
	Actors.setCarrying(actor, false)
end

-- Food owned by `team` still sitting on its counter / roof (for raiders):
-- position and whether it's on a roof.
function FoodService.available(team: string): { { position: Vector3, onRoof: boolean } }
	local list = {}
	for _, item in items do
		if item.food.owner == team and item.food.status == "Pantry" then
			table.insert(list, { position = item.slot, onRoof = item.onRoof })
		end
	end
	return list
end

-- Positions of food `team` dropped on the field (for bots to recover).
function FoodService.droppedBy(team: string): { Vector3 }
	local list = {}
	for _, item in items do
		if item.food.status == "Dropped" and item.food.carrierTeam == team then
			table.insert(list, item.part.Position)
		end
	end
	return list
end

local function step()
	local now = Actors.now()
	local playing = MatchService.isPlaying()

	for _, item in items do
		local ev
		item.food, ev = FoodState.tick(item.food, now, settings)
		if ev then
			showInPantry(item)
		end

		if not playing then
			continue
		end

		local status = item.food.status
		if status == "Pantry" then
			-- Walk up to the counter: horizontal reach + height window (Rules/Reach).
			for _, a in Actors.all() do
				local body, slot = Actors.position(a), item.slot
				if Reach.canGrab({ X = body.X, Y = body.Y, Z = body.Z }, { X = slot.X, Y = slot.Y, Z = slot.Z }, Config.FoodGrab) then
					local nextFood, err = FoodState.pickUp(item.food, actorInput(a))
					if not err then
						item.food = nextFood
						attach(item, a)
						local msg = string.format("%s grabbed %s's %s!", a.name, string.upper(item.food.owner), string.lower(item.food.foodType))
						print("[Food] " .. msg)
						Remotes.announce(msg)
						break
					end
				end
			end
		elseif status == "Carried" then
			local carrier = carrierOf(item)
			if not carrier or carrier.humanoid.Health <= 0 then
				item.food = FoodState.drop(item.food, now)
				showDropped(item, item.part.Position)
			else
				local dropoff = MapService.kitchen(carrier.team).dropoff
				local flat = Vector3.new(dropoff.X, carrier.root.Position.Y, dropoff.Z)
				if (carrier.root.Position - flat).Magnitude <= Config.DropoffRadius then
					local scoredFor
					item.food, scoredFor = FoodState.score(item.food, carrier.team, now, settings)
					if scoredFor then
						Actors.setCarrying(carrier, false)
						hide(item)
						MatchService.awardPoint(scoredFor, carrier)
					end
				end
			end
		elseif status == "Dropped" then
			for _, a in actorsNear(item.part.Position, Config.FoodPickupRadius) do
				local nextFood, result = FoodState.touchDropped(item.food, actorInput(a))
				item.food = nextFood
				if result == "Returned" then
					showInPantry(item)
					break
				elseif result == "PickedUp" then
					attach(item, a)
					break
				end
			end
		end
	end
end

function FoodService.start()
	folder = Instance.new("Folder")
	folder.Name = "Food"
	folder.Parent = Workspace

	local layoutOk, layoutErr = FoodLayout.validate(Config.FoodLayout, Config.FoodTypes)
	assert(layoutOk, "Config.FoodLayout: " .. tostring(layoutErr))

	for _, t in Config.Teams do
		local kitchen = MapService.kitchen(t.id)
		local slots = FoodLayout.slots(Config.FoodLayout, t.id)
		-- Counter positions: base foods first, then any roof food whose
		-- pedestal is missing from the map (fallback).
		local onCounter: { FoodLayout.Slot } = {}
		local placed: { { slot: FoodLayout.Slot, pos: Vector3?, roof: boolean } } = {}
		for _, s in slots do
			local roofPos = if s.kind == "roof" then kitchen.roofFood[s.index] else nil
			if roofPos then
				table.insert(placed, { slot = s, pos = roofPos + Vector3.new(0, 1, 0), roof = true })
			else
				table.insert(onCounter, s)
			end
		end
		local offsets = Reach.slotOffsets(#onCounter)
		for i, s in onCounter do
			local o = offsets[i]
			table.insert(placed, { slot = s, pos = kitchen.pantry + Vector3.new(o.X, o.Y, o.Z), roof = false })
		end
		for _, p in placed do
			for copy = 1, Config.PantrySlotsPerType do
				local foodType = p.slot.foodType
				local item: Item = {
					food = FoodState.new(t.id, foodType),
					part = buildFood(foodType),
					rot = looks[foodType].root.offset,
					-- Extra copies (PantrySlotsPerType > 1) stand side by side, not stacked.
					slot = (p.pos :: Vector3) + Vector3.new(0, 0, (copy - 1) * 1.2),
					onRoof = p.roof,
				}
				-- Clients use these for the food beacon and markers.
				item.part:SetAttribute("Owner", t.id)
				item.part:SetAttribute("OnRoof", p.roof)
				showInPantry(item)
				table.insert(items, item)
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

return FoodService
