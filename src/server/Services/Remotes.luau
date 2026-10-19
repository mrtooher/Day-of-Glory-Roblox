--!strict
-- Creates the RemoteEvents and the replicated MatchState folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local Remotes = {}

local folder: Folder
local events: { [string]: RemoteEvent } = {}
local matchState: Folder

function Remotes.init(_services)
	folder = Instance.new("Folder")
	folder.Name = Net.RemotesFolder
	for _, name in { Net.RequestPower, Net.RequestCharacter, Net.Announce, Net.PlayPowerFx, Net.PowerDenied } do
		local ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = folder
		events[name] = ev
	end
	folder.Parent = ReplicatedStorage

	matchState = Instance.new("Folder")
	matchState.Name = Net.MatchStateFolder
	matchState.Parent = ReplicatedStorage
end

function Remotes.event(name: string): RemoteEvent
	local ev = events[name]
	assert(ev, "unknown remote " .. name)
	return ev
end

-- Replicated match values (scores, phase, timers) live as attributes here.
function Remotes.setState(key: string, value: any)
	matchState:SetAttribute(key, value)
end

function Remotes.announce(text: string)
	events[Net.Announce]:FireAllClients(text)
end

return Remotes
