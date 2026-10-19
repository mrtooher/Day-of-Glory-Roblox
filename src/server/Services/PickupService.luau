--!strict
-- Burger pickups on the field: touch for a short speed burst.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MapService = require(script.Parent.MapService)
local Actors = require(script.Parent.Actors)

local PickupService = {}

local StatusService: any

type Pad = { position: Vector3, part: Part, readyAt: number }
local pads: { Pad } = {}

local TICK = 0.1

function PickupService.init(services)
	StatusService = services.StatusService
end

local function step()
	local now = Actors.now()
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

	task.spawn(function()
		while true do
			step()
			task.wait(TICK)
		end
	end)
end

return PickupService
