--!strict
-- Music and sound effects, played locally on each client.
-- All ids live in Config.Audio; an id of 0 is skipped.
-- SOUND button (bottom-left, next to CHARACTER) mutes / unmutes everything.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local AudioRules = require(ReplicatedStorage.Shared.Rules.AudioRules)

local Audio = {}

local A = Config.Audio

local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local music: Sound
local musicId = 0 -- asset id the music Sound is set to (0 = stopped)
local fadeTween: Tween?
local muted = false

local function fadeTo(volume: number, onDone: (() -> ())?)
	if fadeTween then
		fadeTween:Cancel()
	end
	local tween = TweenService:Create(music, TweenInfo.new(A.fadeSeconds), { Volume = volume })
	fadeTween = tween
	if onDone then
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				onDone()
			end
		end)
	end
	tween:Play()
end

-- Switch the music to track `id` (0 = silence). Same track = keep playing.
local function setMusic(id: number)
	if id == musicId then
		return
	end
	musicId = id
	local uri = AudioRules.assetUri(id)
	if not uri then
		fadeTo(0, function()
			if musicId == 0 then
				music:Stop()
			end
		end)
		return
	end
	music:Stop()
	music.SoundId = uri
	music.Volume = 0
	music.TimePosition = 0
	music:Play()
	fadeTo(A.musicVolume)
end

local function playSfx(name: string)
	local uri = AudioRules.assetUri(A.sfx[name])
	if not uri then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Sfx_" .. name
	s.SoundId = uri
	s.SoundGroup = sfxGroup
	s.Parent = SoundService
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(15, function() -- safety net if Ended never fires (e.g. load failure)
		if s.Parent then
			s:Destroy()
		end
	end)
end

local function makeMuteButton()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SoundToggle"
	gui.ResetOnSpawn = false

	local btn = Instance.new("TextButton")
	btn.Name = "SoundButton"
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.Position = UDim2.new(0, 160, 1, -10) -- right of the CHARACTER button
	btn.Size = UDim2.fromOffset(120, 44)
	btn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	btn.BackgroundTransparency = 0.25
	btn.Font = Enum.Font.GothamBlack
	btn.TextScaled = true
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = "SOUND ON"
	btn.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = btn

	btn.Activated:Connect(function()
		muted = not muted
		musicGroup.Volume = if muted then 0 else 1
		sfxGroup.Volume = if muted then 0 else A.sfxVolume
		btn.Text = if muted then "SOUND OFF" else "SOUND ON"
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Audio.start()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Volume = 1
	musicGroup.Parent = SoundService

	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "Sfx"
	sfxGroup.Volume = A.sfxVolume
	sfxGroup.Parent = SoundService

	music = Instance.new("Sound")
	music.Name = "Music"
	music.Looped = true
	music.Volume = 0
	music.SoundGroup = musicGroup
	music.Parent = SoundService

	makeMuteButton()

	local state = ReplicatedStorage:WaitForChild(Net.MatchStateFolder)
	local remotes = ReplicatedStorage:WaitForChild(Net.RemotesFolder)

	-- Score sound when any team's score goes up (not on the reset to 0).
	local lastScores: { [string]: number } = {}
	for _, t in Config.Teams do
		local key = "Score_" .. t.id
		lastScores[t.id] = state:GetAttribute(key) or 0
		state:GetAttributeChangedSignal(key):Connect(function()
			local v = state:GetAttribute(key) or 0
			if v > lastScores[t.id] then
				playSfx("score")
			end
			lastScores[t.id] = v
		end)
	end

	-- Power sounds, one per power id, on activation.
	local playFx = remotes:WaitForChild(Net.PlayPowerFx) :: RemoteEvent
	playFx.OnClientEvent:Connect(function(_model: Model, powerId: string, data: any)
		local action = if type(data) == "table" then data.action else nil
		if (action or "activate") == "activate" then
			playSfx(powerId)
		end
	end)

	-- Music by phase, countdown beeps, and the "go" sound.
	local lastPhase = state:GetAttribute("Phase") or "Waiting"
	local lastLeft = math.huge
	setMusic(AudioRules.musicFor(lastPhase, A))
	while true do
		local phase = state:GetAttribute("Phase") or "Waiting"
		if phase ~= lastPhase then
			if phase == "Playing" and lastPhase == "Intermission" then
				playSfx("countdownGo")
			end
			lastPhase = phase
			lastLeft = math.huge
			setMusic(AudioRules.musicFor(phase, A))
		end
		if phase == "Intermission" then
			local endsAt = state:GetAttribute("PhaseEndsAt") or 0
			local left = endsAt - Workspace:GetServerTimeNow()
			if AudioRules.countdownCue(lastLeft, left, A.countdownBeepSeconds) then
				playSfx("countdownBeep")
			end
			lastLeft = left
		end
		task.wait(0.1)
	end
end

return Audio
