--!strict
-- Food pieces in the world: pantry restocking, pickup, carrying, dropping
-- and scoring. All decisions go through the pure FoodState rules; this file
-- only measures server-side distances and moves Parts.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FoodState = require(ReplicatedStorage.Shared.Rules.FoodState)
local MapService = require(script.Parent.MapService)
local Actors = require(script.Parent.Actors)
type Actor = Actors.Actor

type Item = {
	food: FoodState.Food,
	part: BasePart,
	slot: Vector3,
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

local looks: { [string]: { shape: Enum.PartType, size: Vector3, color: Color3 } } = {
	Pizza = { shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 2.2, 2.2), color = Color3.fromRGB(255, 170, 60) },
	Burger = { shape = Enum.PartType.Ball, size = Vector3.new(1.8, 1.8, 1.8), color = Color3.fromRGB(150, 90, 40) },
	Taco = { shape = Enum.PartType.Block, size = Vector3.new(2, 1, 1), color = Color3.fromRGB(240, 210, 80) },
	Sushi = { shape = Enum.PartType.Block, size = Vector3.new(1.2, 1.2, 1.2), color = Color3.fromRGB(245, 245, 245) },
}

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
	item.part.CFrame = CFrame.new(item.slot)
	item.part.Parent = folder
end

local function showDropped(item: Item, at: Vector3)
	detach(item)
	item.part.CFrame = CFrame.new(Vector3.new(at.X, 1, at.Z))
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
	p.CFrame = actor.root.CFrame * CFrame.new(0, 3.5, 0)
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
			for _, a in actorsNear(item.part.Position, Config.FoodPickupRadius) do
				local nextFood, err = FoodState.pickUp(item.food, actorInput(a))
				if not err then
					item.food = nextFood
					attach(item, a)
					break
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

	for _, t in Config.Teams do
		local pantry = MapService.kitchen(t.id).pantry
		local n = #Config.FoodTypes * Config.PantrySlotsPerType
		local index = 0
		for _, foodType in Config.FoodTypes do
			for _ = 1, Config.PantrySlotsPerType do
				index += 1
				local z = (index - (n + 1) / 2) * 3
				local look = looks[foodType]
				local p = Instance.new("Part")
				p.Name = foodType
				p.Shape = look.shape
				p.Size = look.size
				p.Color = look.color
				p.Anchored = true
				p.CanCollide = false
				p.Massless = true
				local item: Item = {
					food = FoodState.new(t.id, foodType),
					part = p,
					slot = pantry + Vector3.new(0, 2.5, z),
				}
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
