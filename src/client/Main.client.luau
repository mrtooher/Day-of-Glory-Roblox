--!strict
-- Client entry point. The client only displays state and sends requests;
-- the server decides everything.

local modules = script.Parent

for _, name in { "Hud", "PowerButtons", "CharacterSelect", "Visibility", "PowerFx", "Audio" } do
	local m = require(modules:WaitForChild(name) :: ModuleScript) :: any
	task.spawn(m.start)
end