local AudioRules = require("../../src/shared/Rules/AudioRules")
local Config = require("../../src/shared/Config")

local audio = {
	musicPhases = { "Intermission", "Playing" },
	music = { match = 111, win = 0 },
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
	end)

	t.test("match music in lobby countdown and match only", function()
		t.eq(AudioRules.musicFor("Intermission", audio), 111)
		t.eq(AudioRules.musicFor("Playing", audio), 111)
		t.eq(AudioRules.musicFor("Waiting", audio), 0)
		t.eq(AudioRules.musicFor("PostMatch", audio), 0)
	end)

	t.test("win music used in PostMatch when set", function()
		local a = table.clone(audio)
		a.music = { match = 111, win = 222 }
		t.eq(AudioRules.musicFor("PostMatch", a), 222)
	end)

	t.test("countdown beeps on each of the last 3 seconds only", function()
		t.eq(AudioRules.countdownCue(4.05, 3.95, 3), nil) -- display 5 -> 4
		t.eq(AudioRules.countdownCue(3.05, 2.95, 3), "beep") -- 4 -> 3
		t.eq(AudioRules.countdownCue(2.05, 1.95, 3), "beep") -- 3 -> 2
		t.eq(AudioRules.countdownCue(1.05, 0.95, 3), "beep") -- 2 -> 1
		t.eq(AudioRules.countdownCue(0.05, -0.05, 3), nil) -- 1 -> 0: "go" handles it
		t.eq(AudioRules.countdownCue(2.5, 2.4, 3), nil) -- same second, no repeat
	end)

	t.test("real config: soundtrack set, every power has an sfx slot", function()
		t.eq(Config.Audio.music.match, 140350912499061)
		t.eq(AudioRules.musicFor("Intermission", Config.Audio), 140350912499061)
		t.eq(AudioRules.musicFor("Playing", Config.Audio), 140350912499061)
		for id in Config.Powers do
			t.truthy(Config.Audio.sfx[id] ~= nil, "sfx slot for " .. id)
		end
		t.truthy(Config.Audio.musicVolume > 0 and Config.Audio.musicVolume <= 1, "music volume 0-1")
		t.truthy(Config.Audio.sfxVolume > 0 and Config.Audio.sfxVolume <= 1, "sfx volume 0-1")
	end)
end
