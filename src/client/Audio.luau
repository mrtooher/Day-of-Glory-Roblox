--!strict
-- Music and sound effects, played locally on each client.
-- All ids live in Config.Audio; an id of 0 is skipped. Music = shuffled
-- playlist, next song when one ends.
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
local musicMode = "none" -- "playlist" | "win" | "none"
local trackIndex: number? = nil -- current playlist index
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

local nowPlaying: TextLabel? = nil
local trackToken = 0 -- bumps on every new track; stale timers check it
local failedInARow = 0

local function showNowPlaying(name: string)
	local label = nowPlaying
	if not label then
		return
	end
	label.Text = "♪  NOW PLAYING: " .. name
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.35
	local mine = trackToken
	task.delay(5, function()
		if trackToken == mine then
			TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

local playNextInPlaylist: () -> ()

local function playTrack(id: number, name: string)
	local uri = AudioRules.assetUri(id)
	if not uri then
		return
	end
	trackToken += 1
	local mine = trackToken
	music:Stop()
	music.SoundId = uri
	music.Volume = 0
	music.TimePosition = 0
	music:Play()
	fadeTo(A.musicVolume)
	print(string.format("[Audio] Now playing %s (%.0f)", name, id))
	showNowPlaying(name)
	-- A song that never loads (still in moderation, no permission) would
	-- otherwise stall the playlist forever: skip it.
	task.delay(A.loadTimeoutSeconds, function()
		if trackToken ~= mine then
			return
		end
		if music.IsLoaded then
			failedInARow = 0
			-- Loaded but never started (stuck at 0:00): start it now.
			if not music.IsPlaying and music.TimePosition == 0 and musicMode ~= "none" then
				warn(string.format("[Audio] %s was stuck - starting it again", name))
				music:Play()
			end
			return
		end
		warn(string.format("[Audio] Could not load %s (%.0f) - skipping", name, id))
		failedInARow += 1
		if musicMode == "playlist" and failedInARow < #A.playlist then
			playNextInPlaylist()
		end
	end)
end

playNextInPlaylist = function()
	local count = #A.playlist
	if count == 0 then
		return
	end
	-- First pick: any song (so it doesn't always start with song 1);
	-- after that: any song except the one that just played.
	local roll = if trackIndex == nil then math.random(1, count) else math.random(1, math.max(1, count - 1))
	trackIndex = AudioRules.nextIndex(count, trackIndex, roll)
	local track = A.playlist[trackIndex :: number]
	playTrack(track.id, track.name)
end

-- Switch music mode. Same mode = keep playing (no restart).
local function setMusicMode(mode: string)
	if mode == musicMode then
		return
	end
	musicMode = mode
	failedInARow = 0 -- a new phase gets a fresh set of load attempts
	if mode == "playlist" then
		music.Looped = false
		playNextInPlaylist()
	elseif mode == "win" then
		music.Looped = false
		playTrack(A.winMusic, "Victory")
	else
		fadeTo(0, function()
			if musicMode == "none" then
				music:Stop()
			end
		end)
	end
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
	music.Looped = false
	music.Volume = 0
	music.SoundGroup = musicGroup
	music.Parent = SoundService
	music.Ended:Connect(function()
		-- Roblox ignores Play() called inside this sound's own Ended event:
		-- the next song got its SoundId but sat at 0:00, silent (Jim
		-- 2026-10-22, reproduced in Studio). Start it a moment later instead.
		local endedToken = trackToken
		task.delay(0.1, function()
			if musicMode == "playlist" and trackToken == endedToken then
				playNextInPlaylist()
			end
		end)
	end)

	makeMuteButton()

	-- "NOW PLAYING" label, top-left under the scoreboard area.
	local npGui = Instance.new("ScreenGui")
	npGui.Name = "NowPlaying"
	npGui.ResetOnSpawn = false
	local np = Instance.new("TextLabel")
	np.AnchorPoint = Vector2.new(0, 0)
	np.Position = UDim2.new(0, 12, 0, 60)
	np.Size = UDim2.fromOffset(330, 30)
	np.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	np.BackgroundTransparency = 1
	np.TextTransparency = 1
	np.Font = Enum.Font.GothamBold
	np.TextScaled = true
	np.TextColor3 = Color3.fromRGB(255, 220, 120)
	np.TextXAlignment = Enum.TextXAlignment.Left
	np.Text = ""
	np.Parent = npGui
	local npCorner = Instance.new("UICorner")
	npCorner.CornerRadius = UDim.new(0, 8)
	npCorner.Parent = np
	local npPad = Instance.new("UIPadding")
	npPad.PaddingLeft = UDim.new(0, 8)
	npPad.Parent = np
	npGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	nowPlaying = np

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
	setMusicMode(AudioRules.musicMode(lastPhase, A))
	while true do
		local phase = state:GetAttribute("Phase") or "Waiting"
		if phase ~= lastPhase then
			if phase == "Playing" and lastPhase == "Intermission" then
				playSfx("countdownGo")
			end
			lastPhase = phase
			lastLeft = math.huge
			setMusicMode(AudioRules.musicMode(phase, A))
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
