--!strict
-- Jump pads (Arena parts named JumpPad1..): step on one and get launched up
-- onto the rooftops. Runs on the client because each player's character is
-- physically owned by their own client (server velocity changes don't stick).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PadCooldown = require(ReplicatedStorage.Shared.Rules.PadCooldown)

local Pads = {}

function Pads.start()
	local player = Players.LocalPlayer
	local arena = Workspace:WaitForChild("Arena", 30)
	if not arena then
		return
	end
	local pads: { { name: string, position: Vector3 } } = {}
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") and string.match(d.Name, "^JumpPad%d+$") then
			table.insert(pads, { name = d.Name, position = d.Position })
		end
	end
	if #pads == 0 then
		return
	end

	local cfg = Config.Pads
	local state = PadCooldown.new()
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- No launch while stunned/frozen (server sets "Disabled").
		if root and humanoid and humanoid.Health > 0 and character:GetAttribute("Disabled") ~= true then
			local pos = root.Position
			for _, pad in pads do
				local dx, dz = pos.X - pad.position.X, pos.Z - pad.position.Z
				if dx * dx + dz * dz <= cfg.radius * cfg.radius and math.abs(pos.Y - pad.position.Y) < 6 then
					if PadCooldown.tryUse(state, "me", pad.name, Workspace:GetServerTimeNow(), cfg.cooldownSeconds) then
						local v = root.AssemblyLinearVelocity
						root.AssemblyLinearVelocity = Vector3.new(v.X, cfg.jumpVelocity, v.Z)
						humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
					end
				end
			end
		end
		task.wait(0.05)
	end
end

return Pads
