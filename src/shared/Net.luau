--!strict
-- Names shared by server and client for remotes and replicated state.
return {
	RemotesFolder = "Remotes",
	MatchStateFolder = "MatchState",

	-- client -> server
	RequestPower = "RequestPower", -- no arguments; server uses its own positions
	RequestCharacter = "RequestCharacter", -- (characterId: string)

	-- server -> client
	Announce = "Announce", -- (text: string)
	PlayPowerFx = "PlayPowerFx", -- (model: Model, powerId: string, data: any)
}