--!strict
-- Lifecycle of one piece of food that belongs to a pantry slot.
--
--   Pantry --pickUp(enemy)--> Carried --score(at carrier's dropoff)--> Restocking --tick--> Pantry
--                               |  ^
--                          drop |  | touchDropped(carrier's teammate)
--                               v  |
--                             Dropped --touchDropped(owner team) / tick(expired)--> Pantry

export type Status = "Pantry" | "Carried" | "Dropped" | "Restocking"

export type Food = {
	status: Status,
	owner: string, -- team whose pantry this food belongs to
	foodType: string,
	carrier: string?, -- actor id while Carried
	carrierTeam: string?, -- raiding team while Carried or Dropped
	droppedAt: number?,
	readyAt: number?,
}

export type Actor = {
	id: string,
	team: string,
	carrying: boolean,
}

export type Settings = {
	droppedSeconds: number,
	restockSeconds: number,
}

local FoodState = {}

function FoodState.new(owner: string, foodType: string): Food
	return { status = "Pantry", owner = owner, foodType = foodType }
end

local function inPantry(food: Food): Food
	return { status = "Pantry", owner = food.owner, foodType = food.foodType }
end

local function carriedBy(food: Food, actor: Actor): Food
	return {
		status = "Carried",
		owner = food.owner,
		foodType = food.foodType,
		carrier = actor.id,
		carrierTeam = actor.team,
	}
end

-- Grab from the pantry. Returns the unchanged food and a reason on failure.
function FoodState.pickUp(food: Food, actor: Actor): (Food, string?)
	if actor.carrying then
		return food, "already carrying"
	end
	if food.status ~= "Pantry" then
		return food, "not in pantry"
	end
	if actor.team == food.owner then
		return food, "own pantry"
	end
	return carriedBy(food, actor), nil
end

function FoodState.drop(food: Food, now: number): Food
	if food.status ~= "Carried" then
		error("FoodState.drop: food is " .. food.status)
	end
	return {
		status = "Dropped",
		owner = food.owner,
		foodType = food.foodType,
		carrierTeam = food.carrierTeam,
		droppedAt = now,
	}
end

-- An actor touched dropped food. Owner team returns it; the raiding team picks it up.
function FoodState.touchDropped(food: Food, actor: Actor): (Food, ("Returned" | "PickedUp")?)
	if food.status ~= "Dropped" then
		return food, nil
	end
	if actor.team == food.owner then
		return inPantry(food), "Returned"
	end
	if actor.team == food.carrierTeam and not actor.carrying then
		return carriedBy(food, actor), "PickedUp"
	end
	return food, nil
end

-- Carrier reached the dropoff of `dropoffTeam`. Returns the team that scored, if any.
function FoodState.score(food: Food, dropoffTeam: string, now: number, settings: Settings): (Food, string?)
	if food.status ~= "Carried" or food.carrierTeam ~= dropoffTeam then
		return food, nil
	end
	return {
		status = "Restocking",
		owner = food.owner,
		foodType = food.foodType,
		readyAt = now + settings.restockSeconds,
	},
		dropoffTeam
end

function FoodState.tick(food: Food, now: number, settings: Settings): (Food, ("Expired" | "Restocked")?)
	if food.status == "Dropped" and food.droppedAt and now - food.droppedAt >= settings.droppedSeconds then
		return inPantry(food), "Expired"
	end
	if food.status == "Restocking" and food.readyAt and now >= food.readyAt then
		return inPantry(food), "Restocked"
	end
	return food, nil
end

return FoodState
