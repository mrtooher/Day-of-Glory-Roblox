--!strict
local Lighting = game:GetService("Lighting")

local MapBuildings = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function wedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	for k, v in props do
		(w :: any)[k] = v
	end
	return w
end

local function addSign(parent: Instance, text: string, position: Vector3, size: Vector3, color: Color3, textColor: Color3)
	local sign = part({
		Name = "Sign_" .. text,
		Size = size,
		Position = position,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.Parent = gui
end

function MapBuildings.buildArena(folder: Instance, m: { [string]: any })
	local wallHeight = m.wallHeight or 20
	local halfLen = m.fieldLength / 2
	local halfWid = m.fieldWidth / 2
	local wallColor = Color3.fromRGB(60, 60, 70)

	-- 1. Outer boundary walls
	part({ Name = "WallNorth", Size = Vector3.new(m.fieldLength, wallHeight, 2), Position = Vector3.new(0, wallHeight/2, halfWid), Color = wallColor, Parent = folder })
	part({ Name = "WallSouth", Size = Vector3.new(m.fieldLength, wallHeight, 2), Position = Vector3.new(0, wallHeight/2, -halfWid), Color = wallColor, Parent = folder })
	part({ Name = "WallEast", Size = Vector3.new(2, wallHeight, m.fieldWidth), Position = Vector3.new(halfLen, wallHeight/2, 0), Color = wallColor, Parent = folder })
	part({ Name = "WallWest", Size = Vector3.new(2, wallHeight, m.fieldWidth), Position = Vector3.new(-halfLen, wallHeight/2, 0), Color = wallColor, Parent = folder })

	-- 2. Ground / Streets
	part({ Name = "Ground", Size = Vector3.new(m.fieldLength, 1, m.fieldWidth), Position = Vector3.new(0, -0.5, 0), Color = Color3.fromRGB(110, 170, 90), Material = Enum.Material.Grass, Parent = folder })
	part({ Name = "MainStreet", Size = Vector3.new(m.fieldLength - 40, 0.2, 40), Position = Vector3.new(0, 0.1, 0), Color = Color3.fromRGB(80, 80, 80), Material = Enum.Material.SmoothPlastic, Parent = folder })
	part({ Name = "AlleyNorth", Size = Vector3.new(m.fieldLength - 40, 0.2, 20), Position = Vector3.new(0, 0.1, halfWid - 20), Color = Color3.fromRGB(100, 100, 100), Material = Enum.Material.SmoothPlastic, Parent = folder })
	part({ Name = "AlleySouth", Size = Vector3.new(m.fieldLength - 40, 0.2, 20), Position = Vector3.new(0, 0.1, -halfWid + 20), Color = Color3.fromRGB(100, 100, 100), Material = Enum.Material.SmoothPlastic, Parent = folder })
	part({ Name = "SidewalkNorth1", Size = Vector3.new(m.fieldLength - 40, 0.4, 18), Position = Vector3.new(0, 0.2, halfWid - 49), Color = Color3.fromRGB(200, 200, 200), Material = Enum.Material.Concrete, Parent = folder })
	part({ Name = "SidewalkSouth1", Size = Vector3.new(m.fieldLength - 40, 0.4, 18), Position = Vector3.new(0, 0.2, -halfWid + 49), Color = Color3.fromRGB(200, 200, 200), Material = Enum.Material.Concrete, Parent = folder })
	part({ Name = "SidewalkNorth2", Size = Vector3.new(m.fieldLength - 40, 0.4, 18), Position = Vector3.new(0, 0.2, 29), Color = Color3.fromRGB(200, 200, 200), Material = Enum.Material.Concrete, Parent = folder })
	part({ Name = "SidewalkSouth2", Size = Vector3.new(m.fieldLength - 40, 0.4, 18), Position = Vector3.new(0, 0.2, -29), Color = Color3.fromRGB(200, 200, 200), Material = Enum.Material.Concrete, Parent = folder })
	part({ Name = "RedBaseFloor", Size = Vector3.new(40, 0.2, m.fieldWidth), Position = Vector3.new(-halfLen + 20, 0.1, 0), Color = Color3.fromRGB(180, 60, 60), Material = Enum.Material.SmoothPlastic, Parent = folder })
	part({ Name = "BlueBaseFloor", Size = Vector3.new(40, 0.2, m.fieldWidth), Position = Vector3.new(halfLen - 20, 0.1, 0), Color = Color3.fromRGB(60, 60, 180), Material = Enum.Material.SmoothPlastic, Parent = folder })

	-- 3. Red Base (Pizza Shop)
	local redColor = BrickColor.new("Bright red").Color
	part({ Name = "RedPantry", Size = Vector3.new(10, 4, 16), Position = Vector3.new(-m.pantryX, 2, 0), Color = redColor, Material = Enum.Material.WoodPlanks, Parent = folder })
	part({ Name = "RedCounter", Size = Vector3.new(2, 3, 12), Position = Vector3.new(-m.pantryX + 3, 1.5, 0), Color = Color3.fromRGB(200, 200, 200), Parent = folder })
	part({ Name = "RedDropoff", Size = Vector3.new(12, 0.2, 12), Position = Vector3.new(-m.dropoffX, 0.3, m.dropoffZ), Color = redColor, Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false, Parent = folder })
	
	local redSpawn = Instance.new("SpawnLocation")
	redSpawn.Name = "RedSpawn"
	redSpawn.Anchored = true
	redSpawn.Size = Vector3.new(8, 1, 8)
	redSpawn.Position = Vector3.new(-m.spawnX, 0.5, m.spawnZ)
	redSpawn.BrickColor = BrickColor.new("Bright red")
	redSpawn.TeamColor = BrickColor.new("Bright red")
	redSpawn.Neutral = false
	redSpawn.AllowTeamChangeOnTouch = false
	redSpawn.Duration = 0
	redSpawn.Parent = folder

	part({ Name = "RedRoof", Size = Vector3.new(30, 2, 40), Position = Vector3.new(-185, 8, 0), Color = Color3.fromRGB(150, 40, 40), Parent = folder })
	part({ Name = "RedWallBack", Size = Vector3.new(2, 8, 40), Position = Vector3.new(-200, 4, 0), Color = Color3.fromRGB(180, 60, 60), Parent = folder })
	part({ Name = "RedWallLeft", Size = Vector3.new(30, 8, 2), Position = Vector3.new(-185, 4, 20), Color = Color3.fromRGB(180, 60, 60), Parent = folder })
	part({ Name = "RedWallRight", Size = Vector3.new(30, 8, 2), Position = Vector3.new(-185, 4, -20), Color = Color3.fromRGB(180, 60, 60), Parent = folder })
	addSign(folder, "PIZZA", Vector3.new(-185, 10, 0), Vector3.new(20, 4, 2), Color3.fromRGB(255, 200, 0), Color3.fromRGB(150, 0, 0))

	-- 4. Blue Base (Taco Shop)
	local blueColor = BrickColor.new("Bright blue").Color
	part({ Name = "BluePantry", Size = Vector3.new(10, 4, 16), Position = Vector3.new(m.pantryX, 2, 0), Color = blueColor, Material = Enum.Material.WoodPlanks, Parent = folder })
	part({ Name = "BlueCounter", Size = Vector3.new(2, 3, 12), Position = Vector3.new(m.pantryX - 3, 1.5, 0), Color = Color3.fromRGB(200, 200, 200), Parent = folder })
	part({ Name = "BlueDropoff", Size = Vector3.new(12, 0.2, 12), Position = Vector3.new(m.dropoffX, 0.3, m.dropoffZ), Color = blueColor, Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false, Parent = folder })
	
	local blueSpawn = Instance.new("SpawnLocation")
	blueSpawn.Name = "BlueSpawn"
	blueSpawn.Anchored = true
	blueSpawn.Size = Vector3.new(8, 1, 8)
	blueSpawn.Position = Vector3.new(m.spawnX, 0.5, m.spawnZ)
	blueSpawn.BrickColor = BrickColor.new("Bright blue")
	blueSpawn.TeamColor = BrickColor.new("Bright blue")
	blueSpawn.Neutral = false
	blueSpawn.AllowTeamChangeOnTouch = false
	blueSpawn.Duration = 0
	blueSpawn.Parent = folder

	part({ Name = "BlueRoof", Size = Vector3.new(30, 2, 40), Position = Vector3.new(185, 8, 0), Color = Color3.fromRGB(40, 40, 150), Parent = folder })
	part({ Name = "BlueWallBack", Size = Vector3.new(2, 8, 40), Position = Vector3.new(200, 4, 0), Color = Color3.fromRGB(60, 60, 180), Parent = folder })
	part({ Name = "BlueWallLeft", Size = Vector3.new(30, 8, 2), Position = Vector3.new(185, 4, 20), Color = Color3.fromRGB(60, 60, 180), Parent = folder })
	part({ Name = "BlueWallRight", Size = Vector3.new(30, 8, 2), Position = Vector3.new(185, 4, -20), Color = Color3.fromRGB(60, 60, 180), Parent = folder })
	addSign(folder, "TACOS", Vector3.new(185, 10, 0), Vector3.new(20, 4, 2), Color3.fromRGB(0, 200, 100), Color3.fromRGB(0, 100, 50))

	-- 5. Middle Plaza
	
	for i, b in m.burgerSpawns do
		part({
			Name = "BurgerSpawn" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 5, 5),
			CFrame = CFrame.new(b.x, 0.5, b.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 200, 60),
			CanCollide = false,
			Parent = folder,
		})
	end

	-- 6. Buildings between bases
	local buildings = {
		{ x = -120, z = 50, w = 30, d = 30, h = 12, color = Color3.fromRGB(255, 150, 50), name = "SushiBar", sign = "SUSHI" },
		{ x = -70, z = 50, w = 30, d = 30, h = 16, color = Color3.fromRGB(50, 150, 255), name = "Bank", sign = "BANK" },
		{ x = -120, z = -50, w = 30, d = 30, h = 10, color = Color3.fromRGB(100, 200, 100), name = "BurgerJoint", sign = "BURGERS" },
		{ x = -70, z = -50, w = 30, d = 30, h = 14, color = Color3.fromRGB(200, 100, 200), name = "Police", sign = "POLICE" },
		{ x = 120, z = 50, w = 30, d = 30, h = 14, color = Color3.fromRGB(255, 100, 100), name = "Apartments", sign = "APTS" },
		{ x = 70, z = 50, w = 30, d = 30, h = 12, color = Color3.fromRGB(255, 255, 100), name = "Cafe", sign = "CAFE" },
		{ x = 120, z = -50, w = 30, d = 30, h = 16, color = Color3.fromRGB(100, 100, 255), name = "Arcade", sign = "ARCADE" },
		{ x = 70, z = -50, w = 30, d = 30, h = 10, color = Color3.fromRGB(255, 100, 255), name = "Shop", sign = "SHOP" },
	}
	
	for _, bldg in buildings do
		part({ Name = bldg.name, Size = Vector3.new(bldg.w, bldg.h, bldg.d), Position = Vector3.new(bldg.x, bldg.h/2, bldg.z), Color = bldg.color, Material = Enum.Material.SmoothPlastic, Parent = folder })
		addSign(folder, bldg.sign, Vector3.new(bldg.x, bldg.h + 2, bldg.z > 0 and bldg.z - bldg.d/2 - 1 or bldg.z + bldg.d/2 + 1), Vector3.new(bldg.w - 4, 4, 2), Color3.fromRGB(255, 255, 255), bldg.color)
		part({ Name = bldg.name .. "Crate1", Size = Vector3.new(3, 3, 3), Position = Vector3.new(bldg.x - 10, 1.5, bldg.z > 0 and bldg.z - 20 or bldg.z + 20), Color = Color3.fromRGB(139, 69, 19), Material = Enum.Material.WoodPlanks, Parent = folder })
		part({ Name = bldg.name .. "Crate2", Size = Vector3.new(3, 3, 3), Position = Vector3.new(bldg.x + 10, 1.5, bldg.z > 0 and bldg.z - 20 or bldg.z + 20), Color = Color3.fromRGB(139, 69, 19), Material = Enum.Material.WoodPlanks, Parent = folder })
	end

	-- Stairs up to the Burger Joint roof (roof top at y = 10, front face at z = -35)
	for i = 1, 5 do
		local top = i * 2
		part({ Name = "BurgerJointStep" .. i, Size = Vector3.new(6, top, 2), Position = Vector3.new(-120, top / 2, -23 - i * 2), Color = Color3.fromRGB(139, 69, 19), Material = Enum.Material.WoodPlanks, Parent = folder })
	end

	-- 7. Raised walkway / bridge over middle street
	part({ Name = "BridgeDeck", Size = Vector3.new(10, 1, 44), Position = Vector3.new(0, 10, 0), Color = Color3.fromRGB(150, 150, 150), Material = Enum.Material.Concrete, Parent = folder })
	part({ Name = "BridgeSupport1", Size = Vector3.new(2, 10, 2), Position = Vector3.new(-20, 5, -20), Color = Color3.fromRGB(100, 100, 100), Parent = folder })
	part({ Name = "BridgeSupport2", Size = Vector3.new(2, 10, 2), Position = Vector3.new(20, 5, -20), Color = Color3.fromRGB(100, 100, 100), Parent = folder })
	part({ Name = "BridgeSupport3", Size = Vector3.new(2, 10, 2), Position = Vector3.new(-20, 5, 20), Color = Color3.fromRGB(100, 100, 100), Parent = folder })
	part({ Name = "BridgeSupport4", Size = Vector3.new(2, 10, 2), Position = Vector3.new(20, 5, 20), Color = Color3.fromRGB(100, 100, 100), Parent = folder })
	
	-- Each ramp is 42 long (local Z) and 44 wide (local X), rising 10 to the deck.
	wedge({ Name = "RampWest", Size = Vector3.new(44, 10, 42), CFrame = CFrame.new(-26, 5, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(150, 150, 150), Material = Enum.Material.Concrete, Parent = folder })
	wedge({ Name = "RampEast", Size = Vector3.new(44, 10, 42), CFrame = CFrame.new(26, 5, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = Color3.fromRGB(150, 150, 150), Material = Enum.Material.Concrete, Parent = folder })

	-- 8. Lighting setup
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.ColorShift_Top = Color3.fromRGB(200, 220, 255)
	
	if not Lighting:FindFirstChild("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Color = Color3.fromRGB(150, 180, 220)
		atm.Decay = Color3.fromRGB(100, 130, 180)
		atm.Offset = 0.2
		atm.Parent = Lighting
	end
	
	if not Lighting:FindFirstChild("Bloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.5
		bloom.Size = 20
		bloom.Threshold = 0.8
		bloom.Parent = Lighting
	end
end

return MapBuildings