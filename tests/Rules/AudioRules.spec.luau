local AudioRules = require("../../src/shared/Rules/AudioRules")
local Config = require("../../src/shared/Config")

local audio = {
	musicPhases = { "Intermission", "Playing" },
	playlist = { 111, 222, 333 },
	winMusic = 0,
	sfx = {},
	countdownBeepSeconds = 3,
}

return function(t)
	t.test("assetUri skips 0 and nil", function()
		t.eq(AudioRules.assetUri(0), nil)
		t.eq(AudioRules.assetUri(nil), nil)
	end)

	t.test("assetUri formats large ids without exponent", function()
		t.eq(AudioRules.assetUri(140350912499061), "rbxassetid://140350912499061")
		t.eq(AudioRules.assetUri(89048811438062), "rbxassetid://89048811438062")
	end)

	t.test("playlist in countdown and match only", function()
		t.eq(AudioRules.musicMode("Intermission", audio), "playlist")
		t.eq(AudioRules.musicMode("Playing", audio), "playlist")
		t.eq(AudioRules.musicMode("Waiting", audio), "none")
		t.eq(AudioRules.musicMode("PostMatch", audio), "none")
	end)

	t.test("win music in PostMatch when set; empty playlist = none", function()
		local a = table.clone(audio)
		a.winMusic = 999
		t.eq(AudioRules.musicMode("PostMatch", a), "win")
		a.playlist = {}
		t.eq(AudioRules.musicMode("Playing", a), "none")
	end)

	t.test("shuffle never repeats the song that just played", function()
		for last = 1, 3 do
			for roll = 1, 2 do
				local n = AudioRules.nextIndex(3, last, roll)
				t.truthy(n >= 1 and n <= 3, "in range")
				t.truthy(n ~= last, "no repeat")
			end
		end
	end)

	t.test("shuffle reaches every other song", function()
		local seen = {}
		for roll = 1, 2 do
			seen[AudioRules.nextIndex(3, 1, roll)] = true
		end
		t.truthy(seen[2] and seen[3], "both other songs reachable")
	end)

	t.test("shuffle first pick and single-song playlist", function()
		t.eq(AudioRules.nextIndex(3, nil, 2), 2)
		t.eq(AudioRules.nextIndex(1, 1, 1), 1)
		t.eq(AudioRules.nextIndex(1, nil, 1), 1)
	end)

	t.test("countdown beeps on each of the last 3 seconds only", function()
		t.eq(AudioRules.countdownCue(4.05, 3.95, 3), nil) -- display 5 -> 4
		t.eq(AudioRules.countdownCue(3.05, 2.95, 3), "beep") -- 4 -> 3
		t.eq(AudioRules.countdownCue(2.05, 1.95, 3), "beep") -- 3 -> 2
		t.eq(AudioRules.countdownCue(1.05, 0.95, 3), "beep") -- 2 -> 1
		t.eq(AudioRules.countdownCue(0.05, -0.05, 3), nil) -- 1 -> 0: "go" handles it
		t.eq(AudioRules.countdownCue(2.5, 2.4, 3), nil) -- same second, no repeat
	end)

	t.test("real config: 3-song playlist, every power has an sfx slot", function()
		t.eq(#Config.Audio.playlist, 3)
		t.eq(Config.Audio.playlist[1], 140350912499061)
		t.eq(Config.Audio.playlist[2], 107858682693210)
		t.eq(Config.Audio.playlist[3], 89048811438062)
		t.eq(AudioRules.musicMode("Playing", Config.Audio), "playlist")
		for id in Config.Powers do
			t.truthy(Config.Audio.sfx[id] ~= nil, "sfx slot for " .. id)
		end
		t.truthy(Config.Audio.musicVolume > 0 and Config.Audio.musicVolume <= 1, "music volume 0-1")
		t.truthy(Config.Audio.sfxVolume > 0 and Config.Audio.sfxVolume <= 1, "sfx volume 0-1")
	end)
end
