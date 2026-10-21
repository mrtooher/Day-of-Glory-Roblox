--!strict
-- Client-side visuals driven by server attributes:
--   * vanished enemies are hidden (teammates see them faded)
--   * food carriers get a marker above their head
--   * Dog's SNIFF reveals vanished enemies and highlights carriers through walls
-- These are visuals only; the server decides tagging and targeting.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Visibility = {}

local function actorModels(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local bots = Workspace:FindFirstChild("Bots")
	if bots then
		for _, m in bots:GetChildren() do
			if m:IsA("Model") then
				table.insert(list, m)
			end
		end
	end
	return list
end

local function setTransparency(model: Model, amount: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = amount
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = amount
		elseif d:IsA("BillboardGui") then
			d.Enabled = amount < 1
		end
	end
end

local function carrierMarker(model: Model, show: boolean)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local marker = root:FindFirstChild("CarrierMarker") :: BillboardGui?
	if show and not marker then
		local gui = Instance.new("BillboardGui")
		gui.Name = "CarrierMarker"
		gui.Size = UDim2.fromOffset(120, 34)
		gui.StudsOffset = Vector3.new(0, 6, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = root :: BasePart
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.Text = "FOOD!"
		l.Parent = gui
		gui.Parent = root
	elseif not show and marker then
		marker:Destroy()
	end
end

local function highlight(model: Model, show: boolean, color: Color3)
	local h = model:FindFirstChild("RevealHighlight") :: Highlight?
	if show and not h then
		local new = Instance.new("Highlight")
		new.Name = "RevealHighlight"
		new.FillTransparency = 0.6
		new.FillColor = color
		new.OutlineColor = color
		new.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		new.Adornee = model
		new.Parent = model
	elseif not show and h then
		h:Destroy()
	end
end

-- "INVISIBLE 4" banner for your own Vex while vanished.
local function makeSelfBanner(player: Player): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "VanishBanner"
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 60)
	label.Size = UDim2.fromOffset(320, 44)
	label.BackgroundColor3 = Color3.fromRGB(90, 40, 140)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Visible = false
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui")
	return label
end

function Visibility.start()
	local player = Players.LocalPlayer
	local state = ReplicatedStorage:WaitForChild(Net.MatchStateFolder)
	local banner = makeSelfBanner(player)
	local selfFaded = false

	while true do
		local myTeam = if player.Team then player.Team:GetAttribute("TeamId") :: string? else nil
		local revealed = myTeam ~= nil
			and Workspace:GetServerTimeNow() < (state:GetAttribute("RevealUntil_" .. myTeam) or 0)

		for _, model in actorModels() do
			local team = model:GetAttribute("Team")
			local enemy = team ~= nil and team ~= myTeam
			local vanished = model:GetAttribute("Vanished") == true
			local carrying = model:GetAttribute("Carrying") == true

			if model == player.Character then
				-- Your own Vex: see-through ghost + countdown so you know it worked.
				-- Only touch transparency on change; the camera also sets it.
				if vanished ~= selfFaded then
					setTransparency(model, if vanished then 0.7 else 0)
					selfFaded = vanished
				end
				local untilT = model:GetAttribute("VanishedUntil") or 0
				local left = untilT - Workspace:GetServerTimeNow()
				banner.Visible = vanished and left > 0
				if banner.Visible then
					banner.Text = string.format("INVISIBLE  %d", math.ceil(left))
				end
			else
				if vanished and enemy and not revealed then
					setTransparency(model, 1)
				elseif vanished then
					setTransparency(model, 0.6)
				else
					setTransparency(model, 0)
				end
			end

			carrierMarker(model, carrying and not (vanished and enemy and not revealed))
			highlight(model, revealed and enemy and (vanished or carrying), Color3.fromRGB(255, 120, 40))
		end
		task.wait(0.15)
	end
end

return Visibility
