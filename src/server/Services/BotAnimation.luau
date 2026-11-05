--!strict
-- Bot leg animations (Jim 2026-11-04: bots' legs didn't move). Bot avatars
-- come with Roblox's Animate LocalScript, but a LocalScript never runs on a
-- server-owned model, so no walk/run/idle ever played. The server plays the
-- same animations (ids read from that script's own Animation children); the
-- Animator replicates them to every client. Not a service: BotService calls
-- attach() for each new bot. Choice of animation: Shared/Rules/BotAnim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotAnim = require(ReplicatedStorage.Shared.Rules.BotAnim)

local BotAnimation = {}

local LOOPED = { idle = true, walk = true, run = true, swim = true, climb = true, sit = true }
local TICK = 0.1

-- First Animation under Animate.<name> (e.g. Animate.run.RunAnim).
local function animationFrom(animate: Instance, name: string): Animation?
	local holder = animate:FindFirstChild(name)
	if not holder then
		return nil
	end
	for _, c in holder:GetChildren() do
		if c:IsA("Animation") and c.AnimationId ~= "" then
			return c
		end
	end
	return nil
end

function BotAnimation.attach(model: Model, humanoid: Humanoid, root: BasePart)
	local animate = model:FindFirstChild("Animate")
	if not animate then
		return -- block-rig fallback has nothing to animate
	end
	if animate:IsA("LocalScript") then
		animate.Enabled = false
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = humanoid
		animator = a
	end
	local tracks: { [string]: AnimationTrack } = {}
	for _, name in { "idle", "walk", "run", "jump", "fall", "climb", "sit", "swim" } do
		local anim = animationFrom(animate, name)
		if anim then
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(anim)
			end)
			if ok and track then
				track.Looped = LOOPED[name] == true
				track.Priority = Enum.AnimationPriority.Core
				tracks[name] = track
			end
		end
	end
	if next(tracks) == nil then
		warn("BotAnimation: no animations found for " .. model.Name)
		return
	end
	local count = 0
	for _ in tracks do
		count += 1
	end
	model:SetAttribute("BotAnimTracks", count) -- for Studio checks

	task.spawn(function()
		local current: string? = nil
		while model.Parent and humanoid.Parent do
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local want = BotAnim.pick(humanoid:GetState().Name, speed)
			if not tracks[want] then
				want = if tracks.run and speed >= BotAnim.IdleBelow then "run" else "idle"
			end
			if want ~= current then
				if current and tracks[current] then
					tracks[current]:Stop(0.2)
				end
				if tracks[want] then
					tracks[want]:Play(0.2)
				end
				current = want
			end
			local t = current and tracks[current]
			if t then
				t:AdjustSpeed(BotAnim.speedScale(current :: string, speed))
			end
			task.wait(TICK)
		end
	end)
end

return BotAnimation
