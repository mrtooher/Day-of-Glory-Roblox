--!strict
-- MapBuildings: builds the placeholder "Arena" entirely from parts (no meshes or
-- image assets). Runs in Studio/servers and offline in Lune (tools/arena-check).
--
-- Layout (X = field length, Z = width, centre line X = 0):
--   Red base  = "Pizza Palace" restaurant, X -200..-160 (opens toward +X)
--   Blue base = "Taco Town" restaurant,    X  160.. 200 (opens toward -X)
--   Main street Z -20..20 (bridge hump X -47..47), sidewalks Z ±(20..35)
--   Shop row Z ±(35..65): 8 buildings at X ±70 / ±120, side streets X ±(85..105),
--   park + fountain at |X| < 55, corner plazas at |X| 137..160
--   Back alleys Z ±(67..83), boundary walls at the field edge.
--
-- Gameplay contract (MapService + tools/arena-check depend on these names):
--   RedPantry/BluePantry (food counter, 4x3x14 at (±pantryX, 1.5, 0)),
--   RedDropoff/BlueDropoff, RedSpawn/BlueSpawn (SpawnLocations),
--   BurgerSpawn1/2, DashPad1..8, JumpPad1..4. Each name is used exactly once;
--   decorative parts always use other names. Keep-clear zones around the
--   kitchens, drop-offs, main street and burger spawns hold no collidable parts.
local Lighting = game:GetService("Lighting")

local MapBuildings = {}

type Spec = { [string]: any }

local V = Vector3.new
local CF = CFrame.new
local C = Color3.fromRGB
local M = Enum.Material

local function ry(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- Cylinders run along their local X axis; UP turns that axis vertical.
local UP = CFrame.Angles(0, 0, math.rad(90))
-- Flips an upright shape upside down (rotation in its own XY plane).
local FLIP = CFrame.Angles(0, 0, math.pi)

-- Palette -------------------------------------------------------------------
local WHITE = C(255, 255, 255)
local BLACK = C(25, 25, 30)
local GOLD = C(255, 200, 50)
local GLASS = C(165, 210, 245)
local LEAF = { C(70, 165, 65), C(95, 190, 70), C(55, 140, 60) }
local WOOD = C(140, 90, 55)
local STEEL = C(195, 200, 205)
local LAMP_GREEN = C(40, 70, 55)
local PICADO = { C(255, 80, 160), C(255, 210, 40), C(0, 200, 190), C(255, 130, 40), C(150, 90, 230), C(90, 200, 80) }

-- Part helpers --------------------------------------------------------------
local function newPart(
	cls: string,
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
	collide: boolean,
	shape: Enum.PartType?
): BasePart
	local p = (Instance.new :: any)(cls) :: BasePart
	p.Name = name
	p.Anchored = true
	if shape then
		(p :: any).Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if not collide then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	return p
end

-- Collidable block.
local function solid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): BasePart
	return newPart("Part", parent, name, size, cf, color, mat, true)
end

-- Non-colliding decoration (safe inside keep-clear zones).
local function deco(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): BasePart
	return newPart("Part", parent, name, size, cf, color, mat, false)
end

-- Flat ground marking: decoration that casts no shadow.
local function flat(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): BasePart
	local p = deco(parent, name, size, cf, color, mat)
	p.CastShadow = false
	return p
end

local function neon(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local p = deco(parent, name, size, cf, color, M.Neon)
	p.CastShadow = false
	return p
end

local function glass(parent: Instance, name: string, size: Vector3, cf: CFrame, tint: Color3?): BasePart
	local p = deco(parent, name, size, cf, tint or GLASS, M.Glass)
	p.Transparency = 0.25
	p.Reflectance = 0.15
	p.CastShadow = false
	return p
end

-- Cylinder along cf's X axis; size = (length, diameter, diameter).
local function cyl(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): BasePart
	return newPart("Part", parent, name, size, cf, color, mat, collide == true, Enum.PartType.Cylinder)
end

-- Vertical cylinder centred at `at`.
local function vcyl(parent: Instance, name: string, height: number, diameter: number, at: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): BasePart
	return cyl(parent, name, V(height, diameter, diameter), at * UP, color, mat, collide)
end

local function ball(parent: Instance, name: string, d: number, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): BasePart
	return newPart("Part", parent, name, V(d, d, d), cf, color, mat, collide == true, Enum.PartType.Ball)
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): BasePart
	return newPart("WedgePart", parent, name, size, cf, color, mat, collide == true)
end

local function light(p: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

local function newFolder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Upright isosceles triangle in cf's XY plane (apex at +Y), thickness along cf Z.
-- WedgeParts are tallest at their local +Z end, so two of them turned ±90° meet
-- along the centre line. Multiply cf by FLIP for an apex-down triangle.
local function triangle(parent: Instance, name: string, halfW: number, height: number, thick: number, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?)
	wedge(parent, name .. "L", V(thick, height, halfW), cf * CF(-halfW / 2, 0, 0) * ry(90), color, mat, collide)
	wedge(parent, name .. "R", V(thick, height, halfW), cf * CF(halfW / 2, 0, 0) * ry(-90), color, mat, collide)
end

-- Straight rope between two points in a frame's XY plane (z fixed).
local function rope(parent: Instance, name: string, frame: CFrame, x1: number, y1: number, x2: number, y2: number, z: number, color: Color3)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	deco(parent, name, V(len, 0.15, 0.15), frame * CF((x1 + x2) / 2, (y1 + y2) / 2, z) * CFrame.Angles(0, 0, math.atan2(dy, dx)), C(60, 60, 60))
end

-- Signs ---------------------------------------------------------------------
local function addLabel(part: BasePart, face: Enum.NormalId, text: string, fg: Color3, stroke: Color3, font: Enum.Font?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.2
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.GothamBlack
	t.TextColor3 = fg
	t.TextStrokeColor3 = stroke
	t.TextStrokeTransparency = 0
	t.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = t
	local s = Instance.new("UIStroke")
	s.Color = stroke
	s.Thickness = 4
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	return gui
end

-- Sign board facing cf's -Z (front). Optional neon border glows around it.
local function sign(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	bg: Color3,
	text: string,
	fg: Color3,
	stroke: Color3,
	border: Color3?,
	font: Enum.Font?,
	bothSides: boolean?
): BasePart
	local board = deco(parent, name, size, cf, bg)
	addLabel(board, Enum.NormalId.Front, text, fg, stroke, font)
	if bothSides then
		addLabel(board, Enum.NormalId.Back, text, fg, stroke, font)
	end
	if border then
		local b = neon(parent, name .. "Glow", V(size.X + 0.8, size.Y + 0.8, math.max(size.Z * 0.6, 0.1)), cf, border)
		light(b, border, 14, 0.6)
	end
	return board
end

-- Billboard that floats over a part (always faces the camera).
local function billboard(part: BasePart, text: string, fg: Color3, offsetY: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Billboard"
	bb.Size = UDim2.new(0, 160, 0, 44)
	bb.StudsOffset = V(0, offsetY, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = fg
	t.TextStrokeColor3 = BLACK
	t.TextStrokeTransparency = 0
	t.Parent = bb
end

-- Facade pieces -------------------------------------------------------------

-- CFrame on a face of a w x d footprint at ground level; its -Z points outward
-- and its X runs along the face. Returns the face width too.
local function faceCF(bcf: CFrame, w: number, d: number, which: string): (CFrame, number)
	if which == "front" then
		return bcf * CF(0, 0, -d / 2), w
	elseif which == "back" then
		return bcf * CF(0, 0, d / 2) * ry(180), w
	elseif which == "left" then
		return bcf * CF(-w / 2, 0, 0) * ry(90), d
	end
	return bcf * CF(w / 2, 0, 0) * ry(-90), d
end

-- Framed glass window on a face (u across, v = centre height).
local function window(parent: Instance, name: string, face: CFrame, u: number, v: number, ww: number, wh: number, frame: Color3)
	deco(parent, name .. "Frame", V(ww + 0.6, wh + 0.6, 0.2), face * CF(u, v, -0.1), frame)
	glass(parent, name, V(ww, wh, 0.2), face * CF(u, v, -0.2))
	deco(parent, name .. "Sill", V(ww + 0.9, 0.3, 0.5), face * CF(u, v - wh / 2 - 0.3, -0.3), frame)
end

-- Big shop display window: frame, dark interior, glass, sill and mullion.
local function shopWindow(parent: Instance, name: string, face: CFrame, u: number, ww: number, frame: Color3)
	deco(parent, name .. "Frame", V(ww + 0.8, 6, 0.2), face * CF(u, 4.4, -0.1), frame)
	deco(parent, name .. "Inside", V(ww, 5.2, 0.05), face * CF(u, 4.4, -0.225), C(45, 50, 65))
	glass(parent, name, V(ww, 5.2, 0.1), face * CF(u, 4.4, -0.3))
	deco(parent, name .. "Sill", V(ww + 1, 0.4, 0.8), face * CF(u, 1.5, -0.4), frame)
	deco(parent, name .. "Mullion", V(0.3, 5.2, 0.15), face * CF(u, 4.4, -0.42), frame)
end

-- Striped awning on a face: slopes from `top` at the wall down by `drop`
-- over `depth` studs, with a hanging flap on each stripe.
local function awning(parent: Instance, name: string, face: CFrame, u0: number, top: number, width: number, depth: number, drop: number, colors: { Color3 }, stripeW: number)
	local n = math.max(1, math.floor(width / stripeW + 0.5))
	local sw = width / n
	local len = math.sqrt(depth * depth + drop * drop)
	local tilt = CFrame.Angles(-math.atan(drop / depth), 0, 0)
	for i = 1, n do
		local u = u0 - width / 2 + (i - 0.5) * sw
		local col = colors[(i - 1) % #colors + 1]
		deco(parent, name .. i, V(sw, 0.2, len), face * CF(u, top - drop / 2, -depth / 2) * tilt, col)
		deco(parent, name .. "Flap" .. i, V(sw, 0.9, 0.12), face * CF(u, top - drop - 0.4, -depth), col)
	end
end

-- Street furniture ------------------------------------------------------------

local function tree(parent: Instance, pos: Vector3, s: number?)
	local k = s or 1
	solid(parent, "TreeTrunk", V(1.2 * k, 6 * k, 1.2 * k), CF(pos + V(0, 3 * k, 0)), C(110, 75, 45), M.Wood)
	ball(parent, "TreeLeaves", 7 * k, CF(pos + V(0, 7.5 * k, 0)), LEAF[1], M.Grass)
	ball(parent, "TreeLeaves", 5.5 * k, CF(pos + V(1.7 * k, 9 * k, 0.8 * k)), LEAF[2], M.Grass)
	ball(parent, "TreeLeaves", 4.5 * k, CF(pos + V(-1.3 * k, 10.2 * k, -1 * k)), LEAF[3], M.Grass)
end

-- Street lamp at ground cf; the lamp arm reaches toward cf's -Z.
local function streetLamp(parent: Instance, cf: CFrame)
	solid(parent, "LampBase", V(1.2, 1, 1.2), cf * CF(0, 0.5, 0), LAMP_GREEN, M.Metal)
	vcyl(parent, "LampPole", 10, 0.5, cf * CF(0, 5.5, 0), LAMP_GREEN, M.Metal, true)
	deco(parent, "LampArm", V(0.3, 0.3, 2.8), cf * CF(0, 10.4, -1.2), LAMP_GREEN, M.Metal)
	local head = neon(parent, "LampHead", V(1.2, 0.5, 1.6), cf * CF(0, 10.1, -2.4), C(255, 232, 175))
	light(head, C(255, 210, 150), 22, 1.2)
end

local function bench(parent: Instance, cf: CFrame) -- sitter faces cf's -Z
	solid(parent, "BenchSeat", V(5, 0.4, 1.6), cf * CF(0, 1.5, 0), WOOD, M.WoodPlanks)
	deco(parent, "BenchBack", V(5, 1.4, 0.3), cf * CF(0, 2.6, 0.75), WOOD, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		solid(parent, "BenchLeg", V(0.4, 1.3, 1.4), cf * CF(sx * 2.1, 0.65, 0), BLACK, M.Metal)
	end
end

local function hydrant(parent: Instance, pos: Vector3)
	vcyl(parent, "Hydrant", 2, 1, CF(pos + V(0, 1, 0)), C(220, 40, 40), M.Metal, true)
	ball(parent, "HydrantCap", 1, CF(pos + V(0, 2.05, 0)), C(220, 40, 40), M.Metal)
	deco(parent, "HydrantNozzle", V(1.6, 0.4, 0.4), CF(pos + V(0, 1.3, 0)), C(240, 200, 40), M.Metal)
end

local function trashCan(parent: Instance, pos: Vector3)
	vcyl(parent, "TrashCan", 2.4, 1.6, CF(pos + V(0, 1.2, 0)), C(50, 110, 70), M.Metal, true)
	vcyl(parent, "TrashLid", 0.3, 1.8, CF(pos + V(0, 2.5, 0)), C(35, 80, 50), M.Metal)
end

local function cone(parent: Instance, pos: Vector3)
	solid(parent, "ConeBase", V(1.6, 0.2, 1.6), CF(pos + V(0, 0.1, 0)), C(255, 120, 20))
	vcyl(parent, "Cone", 1.6, 0.9, CF(pos + V(0, 1, 0)), C(255, 120, 20))
	vcyl(parent, "ConeBand", 0.3, 1, CF(pos + V(0, 1.1, 0)), WHITE)
end

local function pottedPlant(parent: Instance, pos: Vector3, flower: Color3?)
	vcyl(parent, "PlantPot", 1.4, 1.8, CF(pos + V(0, 0.7, 0)), C(190, 95, 60), M.SmoothPlastic, true)
	ball(parent, "PlantLeaves", 2.2, CF(pos + V(0, 2.2, 0)), LEAF[2], M.Grass)
	if flower then
		ball(parent, "PlantFlower", 0.8, CF(pos + V(0.5, 3.1, -0.4)), flower)
	end
end

local function planter(parent: Instance, cf: CFrame, colors: { Color3 })
	solid(parent, "Planter", V(4, 1, 2), cf * CF(0, 0.5, 0), WOOD, M.WoodPlanks)
	flat(parent, "PlanterSoil", V(3.6, 0.1, 1.6), cf * CF(0, 1.02, 0), C(90, 60, 40), M.Ground)
	for i, col in colors do
		ball(parent, "PlanterFlower", 1, cf * CF(-1.2 + (i - 1) * 1.2, 1.45, 0), col)
	end
end

-- A-frame chalkboard menu facing cf's -Z.
local function aFrame(parent: Instance, name: string, cf: CFrame, text: string)
	local front = deco(parent, name, V(2.6, 3.4, 0.2), cf * CF(0, 1.7, -0.35) * CFrame.Angles(math.rad(12), 0, 0), C(40, 50, 45))
	addLabel(front, Enum.NormalId.Front, text, WHITE, C(20, 25, 20), Enum.Font.FredokaOne)
	deco(parent, name .. "Back", V(2.6, 3.4, 0.2), cf * CF(0, 1.7, 0.35) * CFrame.Angles(math.rad(-12), 0, 0), WOOD, M.Wood)
end

-- Café table with two chairs and an optional umbrella; cf at floor level.
local function cafeTable(parent: Instance, cf: CFrame, chair: Color3, umbrella: { Color3 }?)
	solid(parent, "TableLeg", V(0.4, 2.6, 0.4), cf * CF(0, 1.3, 0), C(60, 60, 65), M.Metal)
	vcyl(parent, "TableTop", 0.2, 3.4, cf * CF(0, 2.7, 0), WHITE, M.SmoothPlastic, true)
	for _, sx in { -1, 1 } do
		local c = cf * CF(sx * 2.6, 0, 0) * ry(sx > 0 and 90 or -90)
		solid(parent, "ChairSeat", V(1.6, 0.3, 1.6), c * CF(0, 1.6, 0), chair, M.SmoothPlastic)
		deco(parent, "ChairPost", V(0.3, 1.5, 0.3), c * CF(0, 0.75, 0), C(60, 60, 65), M.Metal)
		deco(parent, "ChairBack", V(1.6, 1.6, 0.25), c * CF(0, 2.5, 0.75), chair, M.SmoothPlastic)
	end
	if umbrella then
		deco(parent, "UmbrellaPole", V(0.25, 5.4, 0.25), cf * CF(0, 5.5, 0), WHITE, M.Metal)
		vcyl(parent, "Umbrella", 0.3, 7.5, cf * CF(0, 7.7, 0), umbrella[1])
		vcyl(parent, "UmbrellaMid", 0.35, 5, cf * CF(0, 8.0, 0), umbrella[2])
		vcyl(parent, "UmbrellaTop", 0.4, 2.2, cf * CF(0, 8.3, 0), umbrella[1])
	end
end

-- Parked car along cf's X axis; cf at road level.
local function car(parent: Instance, cf: CFrame, body: Color3, kind: string?)
	solid(parent, "CarBody", V(8, 1.8, 3.6), cf * CF(0, 1.6, 0), body)
	solid(parent, "CarCabin", V(4.4, 1.5, 3.3), cf * CF(-0.4, 3.25, 0), body)
	glass(parent, "CarWindows", V(4.5, 1.1, 3.4), cf * CF(-0.4, 3.3, 0), C(80, 120, 160))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cyl(parent, "CarWheel", V(0.8, 1.8, 1.8), cf * CF(sx * 2.6, 0.9, sz * 1.6) * ry(90), BLACK)
		end
		neon(parent, "CarHeadlight", V(0.1, 0.5, 0.8), cf * CF(4.05, 1.9, sx * 1.1), C(255, 250, 220))
	end
	if kind == "police" then
		deco(parent, "CarStripe", V(8.05, 0.5, 3.65), cf * CF(0, 1.7, 0), WHITE)
		local r = neon(parent, "CarSirenRed", V(0.8, 0.4, 1.4), cf * CF(-0.4, 4.2, -0.8), C(255, 40, 40))
		local b = neon(parent, "CarSirenBlue", V(0.8, 0.4, 1.4), cf * CF(-0.4, 4.2, 0.8), C(40, 120, 255))
		light(r, C(255, 40, 40), 10, 1)
		light(b, C(40, 120, 255), 10, 1)
	elseif kind == "taxi" then
		sign(parent, "TaxiSign", V(1.8, 0.7, 0.8), cf * CF(-0.4, 4.35, 0) * ry(90), C(255, 220, 40), "TAXI", BLACK, C(255, 240, 150), nil, nil, true)
	end
end

-- String of lights / paper flags strung across a frame's X axis, sagging in the middle.
local function bunting(parent: Instance, name: string, frame: CFrame, x1: number, y1: number, x2: number, y2: number, z: number, count: number, flags: boolean)
	local mx, my = (x1 + x2) / 2, (y1 + y2) / 2 - 1.2
	rope(parent, name .. "Rope", frame, x1, y1, mx, my, z, C(60, 60, 60))
	rope(parent, name .. "Rope", frame, mx, my, x2, y2, z, C(60, 60, 60))
	for i = 1, count do
		local t = i / (count + 1)
		local x, y
		if t < 0.5 then
			local k = t * 2
			x, y = x1 + (mx - x1) * k, y1 + (my - y1) * k
		else
			local k = (t - 0.5) * 2
			x, y = mx + (x2 - mx) * k, my + (y2 - my) * k
		end
		if flags then
			deco(parent, name .. "Flag", V(1.3, 1.5, 0.08), frame * CF(x, y - 0.85, z), PICADO[(i - 1) % #PICADO + 1])
		else
			local b = ball(parent, name .. "Bulb", 0.6, frame * CF(x, y - 0.35, z), C(255, 235, 170), M.Neon)
			if i % 3 == 0 then
				light(b, C(255, 220, 160), 10, 0.6)
			end
		end
	end
end

-- Generic shop building -----------------------------------------------------
-- A solid core block (so bots path around it as before) dressed with plinth,
-- cornice, parapet, storefront windows, door, awning, sign and side windows.

local function buildShop(root: Instance, b: Spec)
	local f = newFolder(root, b.name)
	local w: number, d: number, h: number = b.w, b.d, b.h
	local north = b.z > 0
	-- Local frame: origin at footprint centre on the ground, -Z = street side.
	local bcf = CF(b.x, 0, b.z) * (if north then CF() else ry(180))
	local trimMat: Enum.Material = b.trimMat or M.SmoothPlastic

	solid(f, "Walls", V(w, h, d), bcf * CF(0, h / 2, 0), b.wall, b.wallMat)
	solid(f, "Plinth", V(w + 1, 0.8, d + 1), bcf * CF(0, 0.4, 0), C(150, 150, 155), M.Concrete)
	deco(f, "Cornice", V(w + 1.2, 0.8, d + 1.2), bcf * CF(0, h - 0.4, 0), b.trim, trimMat)
	if h > 11 then
		deco(f, "FloorBand", V(w + 0.5, 0.5, d + 0.5), bcf * CF(0, 8.75, 0), b.trim, trimMat)
	end
	flat(f, "RoofCap", V(w - 1.6, 0.1, d - 1.6), bcf * CF(0, h + 0.05, 0), C(75, 75, 82), M.Concrete)
	for _, sx in { -1, 1 } do
		deco(f, "Pilaster", V(1.2, h, 1.2), bcf * CF(sx * w / 2, h / 2, -d / 2), b.trim, trimMat)
	end

	-- Parapet (collidable, low enough to hop over), optional gap at the front.
	if not b.noParapet then
		local py = h + 0.6
		local gap: { number }? = b.parapetGap
		if gap then
			local a1, a2 = -w / 2, gap[1]
			local c1, c2 = gap[2], w / 2
			solid(f, "Parapet", V(a2 - a1, 1.2, 0.8), bcf * CF((a1 + a2) / 2, py, -d / 2 + 0.4), b.trim, trimMat)
			solid(f, "Parapet", V(c2 - c1, 1.2, 0.8), bcf * CF((c1 + c2) / 2, py, -d / 2 + 0.4), b.trim, trimMat)
		else
			solid(f, "Parapet", V(w, 1.2, 0.8), bcf * CF(0, py, -d / 2 + 0.4), b.trim, trimMat)
		end
		solid(f, "Parapet", V(w, 1.2, 0.8), bcf * CF(0, py, d / 2 - 0.4), b.trim, trimMat)
		for _, sx in { -1, 1 } do
			solid(f, "Parapet", V(0.8, 1.2, d - 1.6), bcf * CF(sx * (w / 2 - 0.4), py, 0), b.trim, trimMat)
		end
	end

	-- Storefront: door + display windows on each side.
	local front = faceCF(bcf, w, d, "front")
	local du: number = b.doorU or 0
	deco(f, "DoorFrame", V(5.4, 7.6, 0.2), front * CF(du, 4.6, -0.1), b.trim, trimMat)
	deco(f, "Door", V(4.4, 7, 0.2), front * CF(du, 4.3, -0.25), b.door, M.Wood)
	glass(f, "DoorGlass", V(2.8, 3, 0.1), front * CF(du, 5.6, -0.38))
	deco(f, "DoorHandle", V(0.3, 1, 0.3), front * CF(du + 1.5, 4, -0.45), GOLD, M.Metal)
	for _, sx in { -1, 1 } do
		local inner = du + sx * 3.6
		local outer = sx * (w / 2 - 1.8)
		local ww = math.abs(outer - inner)
		if ww > 2 then
			shopWindow(f, "ShopWindow", front, (inner + outer) / 2, ww, b.trim)
		end
	end
	if b.awning then
		awning(f, "Awning", front, 0, 8.4, w - 2, 3.6, 1.3, b.awning, 2.5)
	end
	if b.sign then
		local sw: number = b.signW or (w - 6)
		sign(f, "StoreSign", V(sw, 3.2, 0.5), front * CF(b.signU or 0, b.signY or 10.8, -0.6), b.signBg, b.sign, b.signFg, b.signStroke, b.signBorder, b.font)
	end

	-- Upper-floor front windows.
	for _, v in (b.frontRows or {}) :: { number } do
		for _, u in (b.frontCols or { -10, -5, 0, 5, 10 }) :: { number } do
			window(f, "Window", front, u, v, 3, 2.4, b.trim)
		end
	end
	-- Side windows.
	for _, side in { "left", "right" } do
		local face = faceCF(bcf, w, d, side)
		for _, v in b.sideRows :: { number } do
			for _, u in { -9, -3, 3, 9 } do
				window(f, "Window", face, u, v, 3, 2.6, b.trim)
			end
		end
	end
	-- Back door onto the alley.
	local back = faceCF(bcf, w, d, "back")
	deco(f, "BackDoor", V(4, 6.8, 0.25), back * CF(6, 4.2, -0.12), C(90, 90, 95), M.Metal)
	solid(f, "BackStep", V(5, 0.6, 1.6), back * CF(6, 0.3, -0.8), C(150, 150, 155), M.Concrete)

	if b.extras then
		(b.extras :: any)(f, bcf, b)
	end
	return f, bcf
end

-- Building extras (local frame: X across the front, -Z = street, y from ground)

local function sushiExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Pagoda-style eave with red trim.
	solid(f, "Eave", V(34, 0.6, 34), L(0, h + 0.3, 0), C(45, 50, 62), M.Slate)
	deco(f, "EaveTrim", V(34.3, 0.3, 34.3), L(0, h + 0.05, 0), C(200, 40, 40))
	solid(f, "Ridge", V(22, 1.4, 22), L(0, h + 1.3, 0), C(55, 60, 72), M.Slate)
	local top = h + 2
	-- Giant maki roll: nori outside, rice ring, salmon/cucumber/avocado centre.
	local roll = L(-5, top + 4.5, 2) * ry(90)
	cyl(f, "MakiNori", V(6, 9, 9), roll, C(25, 45, 35), M.SmoothPlastic, true)
	cyl(f, "MakiRice", V(0.3, 8, 8), roll * CF(3.05, 0, 0), C(250, 250, 245))
	cyl(f, "MakiRiceBack", V(0.3, 8, 8), roll * CF(-3.05, 0, 0), C(250, 250, 245))
	cyl(f, "MakiSalmon", V(0.3, 3.2, 3.2), roll * CF(3.25, 0, 0), C(255, 125, 80))
	cyl(f, "MakiCucumber", V(0.3, 1.5, 1.5), roll * CF(3.3, 1.6, 1.5), C(90, 190, 80))
	cyl(f, "MakiAvocado", V(0.3, 1.5, 1.5), roll * CF(3.3, -1.5, -1.6), C(190, 215, 100))
	-- Giant salmon nigiri.
	solid(f, "NigiriRice", V(7, 2.4, 4), L(6.5, top + 1.2, 2), C(250, 250, 245))
	solid(f, "NigiriSalmon", V(7.6, 1, 4.6), L(6.5, top + 2.9, 2), C(255, 130, 90))
	for k = -1, 1 do
		deco(f, "NigiriStripe", V(0.45, 1.06, 4.66), L(6.5 + k * 2, top + 2.9, 2), C(255, 220, 200))
	end
	-- Chopsticks leaning across the roll.
	for k = 0, 1 do
		deco(f, "Chopstick", V(0.5, 0.5, 14), L(-6 + k * 1.4, top + 7, 4) * CFrame.Angles(math.rad(-30), math.rad(8), 0), C(220, 180, 120), M.Wood)
	end
	-- Red paper lanterns.
	for _, spot in { { -14, 10.4, -17.2 }, { 14, 10.4, -17.2 }, { -4.2, 7.4, -15.9 }, { 4.2, 7.4, -15.9 } } do
		local lc = L(spot[1], spot[2], spot[3])
		local lantern = ball(f, "Lantern", 2.2, lc, C(225, 40, 40))
		light(lantern, C(255, 120, 80), 12, 0.8)
		vcyl(f, "LanternCap", 0.3, 1.2, lc * CF(0, 1.1, 0), BLACK)
		vcyl(f, "LanternCap", 0.3, 1.2, lc * CF(0, -1.1, 0), BLACK)
	end
	-- Noren curtain over the door.
	local front = faceCF(bcf, b.w, b.d, "front")
	for k = -1, 1 do
		deco(f, "Noren", V(1.4, 2.4, 0.1), front * CF(k * 1.5, 6.6, -0.55), C(30, 40, 95))
	end
	-- Bamboo pots and a menu board.
	for _, u in { -13.5, 13.5 } do
		vcyl(f, "BambooPot", 1.4, 2.2, L(u, 1.1, -17), C(60, 60, 65), M.SmoothPlastic, true)
		for k = -1, 1 do
			deco(f, "Bamboo", V(0.35, 6 + k, 0.35), L(u + k * 0.5, 1.8 + (6 + k) / 2, -17 + k * 0.3), C(110, 180, 70), M.Wood)
		end
	end
	aFrame(f, "SushiMenu", L(-8, 0.4, -21), "SUSHI\nMAKI ROLLS\nNIGIRI")
end

local function bankExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	local marble = C(240, 235, 222)
	-- Front steps.
	solid(f, "BankStep", V(26, 0.4, 6), L(0, 0.2, -18), marble, M.Marble)
	solid(f, "BankStep", V(26, 0.8, 4), L(0, 0.4, -17), marble, M.Marble)
	solid(f, "BankStep", V(26, 1.2, 2), L(0, 0.6, -16), marble, M.Marble)
	-- Columns, entablature and pediment.
	for _, u in { -10.5, -3.5, 3.5, 10.5 } do
		vcyl(f, "BankColumn", 12.4, 2, L(u, 6.6, -19.5), marble, M.Marble, true)
		deco(f, "ColumnBase", V(2.8, 0.5, 2.8), L(u, 0.65, -19.5), marble, M.Marble)
		deco(f, "ColumnCap", V(2.8, 0.5, 2.8), L(u, 12.55, -19.5), b.trim, M.Marble)
	end
	solid(f, "Entablature", V(27, 1.6, 6.6), L(0, 13.6, -18.2), marble, M.Marble)
	sign(f, "BankSign", V(20, 1.4, 0.3), L(0, 13.6, -21.65), C(30, 60, 50), "BIG BUCKS BANK", GOLD, C(80, 50, 0), nil)
	triangle(f, "Pediment", 13.5, 4.4, 1, L(0, 16.6, -20.8), marble, M.Marble, true)
	local medal = cyl(f, "PedimentCoin", V(0.3, 2.8, 2.8), L(0, 15.6, -21.4) * ry(90), GOLD, M.Metal)
	addLabel(medal, Enum.NormalId.Right, "$", C(120, 80, 0), C(255, 240, 160))
	-- Giant gold coin and gold bars on the roof.
	local coin = cyl(f, "GiantCoin", V(1.2, 9, 9), L(-5, h + 5.1, 4) * ry(90), GOLD, M.Metal, true)
	cyl(f, "GiantCoinRim", V(1, 9.8, 9.8), L(-5, h + 5.1, 4) * ry(90), C(210, 155, 30), M.Metal)
	addLabel(coin, Enum.NormalId.Right, "$", C(255, 245, 170), C(140, 90, 0))
	addLabel(coin, Enum.NormalId.Left, "$", C(255, 245, 170), C(140, 90, 0))
	light(coin, GOLD, 16, 0.8)
	for i, p in { { 4.5, 0.6 }, { 7.7, 0.6 }, { 10.9, 0.6 }, { 6.1, 1.8 }, { 9.3, 1.8 }, { 7.7, 3.0 } } do
		solid(f, "GoldBar" .. i, V(3, 1.2, 1.6), L(p[1], h + p[2], 4), GOLD, M.Metal)
	end
end

local function cafeExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant coffee cup on a saucer, with steam.
	local cx, cz = -5, 3
	vcyl(f, "Saucer", 0.6, 11, L(cx, h + 0.5, cz), WHITE, M.SmoothPlastic, true)
	vcyl(f, "CupBody", 7, 7.5, L(cx, h + 4.3, cz), WHITE, M.SmoothPlastic, true)
	vcyl(f, "CupBand", 1.4, 7.7, L(cx, h + 4.3, cz), C(120, 70, 40))
	vcyl(f, "Coffee", 0.2, 6.8, L(cx, h + 7.75, cz), C(95, 55, 30))
	deco(f, "CupHandle", V(1.8, 0.8, 0.8), L(cx - 4.4, h + 6.3, cz), WHITE)
	deco(f, "CupHandle", V(1.8, 0.8, 0.8), L(cx - 4.4, h + 2.6, cz), WHITE)
	deco(f, "CupHandle", V(0.8, 4.5, 0.8), L(cx - 5, h + 4.45, cz), WHITE)
	for i, s in { 1.8, 2.4, 3.0 } do
		local puff = ball(f, "Steam", s, L(cx + (i % 2 == 0 and 1 or -0.8), h + 8.5 + i * 1.8, cz), WHITE)
		puff.Transparency = 0.45
	end
	-- Giant pink donut standing on edge, facing the street.
	local dc = L(7, h + 4.1, 4)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		ball(f, "DonutDough", 2.8, dc * CF(math.cos(a) * 2.6, math.sin(a) * 2.6, 0.2), C(225, 165, 95), M.SmoothPlastic, true)
		ball(f, "DonutFrosting", 2.4, dc * CF(math.cos(a) * 2.6, math.sin(a) * 2.6, -0.6), C(255, 130, 185))
	end
	for i, col in { C(255, 255, 255), C(80, 200, 255), C(255, 230, 60), C(120, 230, 120), C(255, 90, 90) } do
		local a = i / 5 * math.pi * 2 + 0.4
		deco(f, "Sprinkle", V(0.7, 0.25, 0.25), dc * CF(math.cos(a) * 2.6, math.sin(a) * 2.6, -1.85) * CFrame.Angles(0, 0, a * 1.7), col)
	end
	-- Sidewalk café.
	for _, u in { -9, 7 } do
		cafeTable(f, L(u, 0.4, -24), C(40, 140, 80), { C(40, 140, 80), C(250, 240, 220) })
	end
	aFrame(f, "CafeMenu", L(-1.5, 0.4, -20), "COFFEE\nCOCOA\nDONUTS")
	pottedPlant(f, (L(-14, 0.4, -17)).Position, C(255, 120, 160))
	pottedPlant(f, (L(14, 0.4, -17)).Position, C(255, 220, 80))
end

local function apartmentExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	local front = faceCF(bcf, b.w, b.d, "front")
	awning(f, "DoorCanopy", front, 0, 8.6, 6, 2.4, 0.8, { C(40, 70, 130), C(250, 250, 250) }, 1.5)
	-- Balconies with railings and flower pots.
	for ri, v in b.frontRows :: { number } do
		for ci, u in { -10, 0, 10 } do
			deco(f, "Balcony", V(4.6, 0.3, 2), front * CF(u, v - 1.75, -1), C(200, 200, 205), M.Concrete)
			deco(f, "BalconyRail", V(4.6, 1.2, 0.2), front * CF(u, v - 1, -2), C(40, 40, 50), M.Metal)
			if (ri + ci) % 2 == 0 then
				ball(f, "BalconyFlowers", 1, front * CF(u + 1.6, v - 1.1, -1.4), C(255, 100, 150))
			end
		end
	end
	-- Rooftop water tower.
	local wx, wz = 6, 5
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			solid(f, "TowerLeg", V(0.5, 5, 0.5), L(wx + sx * 2.2, h + 2.5, wz + sz * 2.2), C(70, 60, 50), M.Metal)
		end
	end
	vcyl(f, "WaterTank", 6, 6, L(wx, h + 8, wz), C(150, 100, 60), M.WoodPlanks, true)
	vcyl(f, "TankBand", 0.3, 6.2, L(wx, h + 6.5, wz), C(60, 60, 65), M.Metal)
	vcyl(f, "TankBand", 0.3, 6.2, L(wx, h + 9.5, wz), C(60, 60, 65), M.Metal)
	vcyl(f, "TankRoof", 0.8, 6.6, L(wx, h + 11.4, wz), C(70, 70, 75), M.Metal)
	vcyl(f, "TankRoof", 0.8, 4.2, L(wx, h + 12.2, wz), C(70, 70, 75), M.Metal)
	vcyl(f, "TankRoof", 0.6, 1.6, L(wx, h + 12.9, wz), C(70, 70, 75), M.Metal)
	-- TV antenna and AC unit.
	deco(f, "Antenna", V(0.2, 5, 0.2), L(-8, h + 2.5, 8), C(80, 80, 85), M.Metal)
	deco(f, "AntennaBar", V(3, 0.2, 0.2), L(-8, h + 4.2, 8), C(80, 80, 85), M.Metal)
	solid(f, "ACUnit", V(3, 2, 3), L(-6, h + 1, -6), C(190, 190, 195), M.Metal)
	vcyl(f, "ACFan", 0.2, 2.2, L(-6, h + 2.05, -6), C(60, 60, 65), M.Metal)
	pottedPlant(f, (L(-4.5, 0.4, -16.6)).Position, C(255, 210, 60))
	pottedPlant(f, (L(4.5, 0.4, -16.6)).Position, C(255, 210, 60))
end

local function burgerExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant burger on the roof (the buns are solid, so you can climb it).
	local bx, bz = -4, 4
	local bun = C(225, 160, 80)
	vcyl(f, "BurgerBunBottom", 2.2, 11, L(bx, h + 1.1, bz), bun, M.SmoothPlastic, true)
	vcyl(f, "BurgerPatty", 2, 11.6, L(bx, h + 3.2, bz), C(110, 60, 35), M.SmoothPlastic, true)
	deco(f, "BurgerCheese", V(11, 0.4, 11), L(bx, h + 4.4, bz) * ry(45), C(255, 205, 40))
	vcyl(f, "BurgerLettuce", 0.6, 12.6, L(bx, h + 4.9, bz), C(100, 195, 60), M.SmoothPlastic, true)
	vcyl(f, "BurgerTomato", 0.8, 10.8, L(bx, h + 5.6, bz), C(230, 50, 40), M.SmoothPlastic, true)
	vcyl(f, "BurgerBunTop", 2, 11, L(bx, h + 7, bz), bun, M.SmoothPlastic, true)
	vcyl(f, "BurgerBunTop", 1.4, 9.6, L(bx, h + 8.7, bz), bun, M.SmoothPlastic, true)
	vcyl(f, "BurgerBunTop", 1, 7, L(bx, h + 9.9, bz), bun, M.SmoothPlastic, true)
	for i, p in { { -3, 9.45, 1.5 }, { 2.5, 9.45, -2 }, { 1, 10.45, 2 }, { -2, 10.45, -1.5 }, { 3.6, 8.05, 3 }, { -4.2, 8.05, -2.5 } } do
		deco(f, "Sesame" .. i, V(0.9, 0.3, 0.5), L(bx + p[1], h + p[2], bz + p[3]) * ry(i * 37), C(255, 245, 220))
	end
	-- Sidewalk tables with red umbrellas and a menu.
	for _, u in { -11, -3 } do
		cafeTable(f, L(u, 0.4, -24), C(220, 40, 40), { C(220, 40, 40), WHITE })
	end
	aFrame(f, "BurgerMenu", L(1.5, 0.4, -20.5), "BURGERS\nFRIES\nSHAKES")
end

local function policeExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Blue door lamps.
	for _, u in { -4.2, 4.2 } do
		deco(f, "DoorLampPost", V(0.3, 1.2, 0.3), L(u, 7.3, -15.6), BLACK, M.Metal)
		local globe = ball(f, "DoorLamp", 1.3, L(u, 8.2, -15.6), C(60, 140, 255), M.Neon)
		light(globe, C(60, 140, 255), 12, 1)
	end
	-- Roof light bar.
	solid(f, "LightBarStand", V(10, 2, 2), L(0, h + 1, 3), C(40, 40, 50), M.Metal)
	solid(f, "LightBar", V(14, 1.4, 3.2), L(0, h + 2.7, 3), WHITE)
	local red = neon(f, "LightBarRed", V(5.5, 1.6, 3.4), L(-3.8, h + 2.7, 3), C(255, 40, 40))
	local blue = neon(f, "LightBarBlue", V(5.5, 1.6, 3.4), L(3.8, h + 2.7, 3), C(40, 110, 255))
	light(red, C(255, 40, 40), 30, 2)
	light(blue, C(40, 110, 255), 30, 2)
	-- Giant gold badge (shield with a star) at the front of the roof.
	local badge = solid(f, "Badge", V(6, 4, 0.8), L(-9, h + 5.2, -10), GOLD, M.Metal)
	addLabel(badge, Enum.NormalId.Front, "★", C(30, 55, 130), C(255, 240, 170))
	triangle(f, "BadgeTip", 3, 3, 0.8, L(-9, h + 1.7, -10) * FLIP, GOLD, M.Metal, true)
	-- Squad car parked at the kerb out front, with traffic cones.
	local kz = if b.z > 0 then 16 else -16
	car(f, CF(b.x, 0.1, kz), C(30, 40, 70), "police")
	for _, dx in { -6, -7.8, 6.2 } do
		cone(f, V(b.x + dx, 0.1, kz))
	end
end

local function shopExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant shopping bag with handles.
	local bag = solid(f, "ShoppingBag", V(7, 8, 3.5), L(-4, h + 4, 3), C(255, 105, 170))
	addLabel(bag, Enum.NormalId.Front, "SHOP!", WHITE, C(150, 20, 90), Enum.Font.FredokaOne)
	deco(f, "BagTop", V(7.1, 0.6, 3.6), L(-4, h + 7.7, 3), WHITE)
	for _, hz in { -1, 1 } do
		for _, hx in { -1.3, 1.3 } do
			deco(f, "BagHandle", V(0.4, 2.4, 0.4), L(-4 + hx, h + 9.2, 3 + hz), C(150, 20, 90))
		end
		deco(f, "BagHandle", V(3, 0.4, 0.4), L(-4, h + 10.4, 3 + hz), C(150, 20, 90))
	end
	-- Gift box with ribbon and bow.
	solid(f, "GiftBox", V(5, 5, 5), L(6, h + 2.5, 3), C(40, 190, 200))
	deco(f, "GiftRibbon", V(1, 5.1, 5.1), L(6, h + 2.5, 3), C(255, 220, 40))
	deco(f, "GiftRibbon", V(5.1, 5.1, 1), L(6, h + 2.5, 3), C(255, 220, 40))
	ball(f, "GiftBow", 1.8, L(5.2, h + 5.6, 3), C(255, 220, 40))
	ball(f, "GiftBow", 1.8, L(6.8, h + 5.6, 3), C(255, 220, 40))
	sign(f, "SaleSign", V(6, 2.4, 0.4), L(9, h + 1.8, -12) * CFrame.Angles(math.rad(10), 0, 0), C(255, 230, 40), "SALE!", C(230, 30, 60), WHITE, nil, Enum.Font.FredokaOne)
	-- Fruit stand out front.
	local stand = L(-8.5, 0.4, -19)
	solid(f, "FruitStand", V(8, 2.6, 3), stand * CF(0, 1.3, 0), WOOD, M.WoodPlanks)
	local fruit = { C(230, 40, 40), C(255, 150, 30), C(120, 200, 60), C(255, 225, 60) }
	for i = 1, 8 do
		ball(f, "Fruit", 0.9, stand * CF(-3.3 + (i - 1) * 0.95, 2.95, (i % 2 == 0) and -0.6 or 0.5), fruit[(i - 1) % 4 + 1])
	end
	awning(f, "StandAwning", stand, 0, 5.2, 8, 3, 0.8, { C(255, 105, 170), WHITE }, 2)
	for _, sx in { -1, 1 } do
		deco(f, "StandPost", V(0.3, 4.5, 0.3), stand * CF(sx * 3.8, 2.25 + 2.6 - 1.3, -2.7), WHITE)
	end
end

local function arcadeExtras(f: Instance, bcf: CFrame, b: Spec)
	local h: number = b.h
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end
	-- Giant joystick.
	solid(f, "JoystickBase", V(9, 2, 7), L(-5, h + 1, 2), BLACK)
	deco(f, "JoystickTrim", V(9.1, 0.4, 7.1), L(-5, h + 1.6, 2), C(255, 60, 200), M.Neon)
	vcyl(f, "JoystickStick", 6, 1.2, L(-6.5, h + 5, 2), C(180, 180, 190), M.Metal, true)
	ball(f, "JoystickBall", 3.6, L(-6.5, h + 8.6, 2), C(235, 35, 50), M.SmoothPlastic, true)
	vcyl(f, "ArcadeButton", 0.6, 1.6, L(-2.5, h + 2.2, 0.5), C(255, 220, 40))
	vcyl(f, "ArcadeButton", 0.6, 1.6, L(-2.5, h + 2.2, 3.5), C(40, 160, 255))
	-- Giant coin.
	local coin = cyl(f, "ArcadeCoin", V(1, 7, 7), L(7, h + 3.7, -2) * ry(90), GOLD, M.Metal, true)
	addLabel(coin, Enum.NormalId.Right, "★", C(255, 250, 200), C(160, 100, 0))
	addLabel(coin, Enum.NormalId.Left, "★", C(255, 250, 200), C(160, 100, 0))
	-- Pixel-art heart (one neon part per run of pixels).
	-- Runs of pixels per row (columns -3..3, row 1 = top).
	local px = 1.4
	local runs = { { { -3, -1 }, { 1, 3 } }, { { -3, 3 } }, { { -3, 3 } }, { { -2, 2 } }, { { -1, 1 } }, { { 0, 0 } } }
	for r, list in runs do
		for _, run in list do
			local n = run[2] - run[1] + 1
			local cx = (run[1] + run[2]) / 2 * px
			neon(f, "PixelHeart", V(n * px, px, 1), L(cx + 3, h + 0.4 + (7 - r) * px, 9), C(255, 50, 100))
		end
	end
	-- Arcade cabinets out front.
	for _, u in { -11, 11 } do
		local cab = L(u, 0.4, -18)
		solid(f, "ArcadeCabinet", V(2.6, 5.5, 2.4), cab * CF(0, 2.75, 0), C(30, 40, 120))
		neon(f, "CabinetScreen", V(2, 1.6, 0.1), cab * CF(0, 3.9, -1.25), C(80, 255, 200))
		neon(f, "CabinetMarquee", V(2.6, 0.8, 0.3), cab * CF(0, 5.2, -1.1), C(255, 60, 200))
		deco(f, "CabinetPanel", V(2.6, 0.4, 1), cab * CF(0, 2.8, -1.6), BLACK)
	end
end

local BUILDINGS: { Spec } = {
	{
		name = "SushiBar", x = -120, z = 50, w = 30, d = 30, h = 13,
		wall = C(115, 75, 50), wallMat = M.WoodPlanks, trim = C(200, 40, 40), door = C(60, 40, 30),
		sign = "SUSHI BAR", signBg = BLACK, signFg = WHITE, signStroke = C(200, 30, 30), signBorder = C(255, 60, 60),
		noParapet = true, sideRows = { 4.5 }, extras = sushiExtras,
	},
	{
		name = "Bank", x = -70, z = 50, w = 30, d = 30, h = 18,
		wall = C(232, 225, 205), wallMat = M.Marble, trim = C(205, 170, 80), door = C(60, 90, 70),
		sideRows = { 4.5, 10.5, 14.5 }, extras = bankExtras,
	},
	{
		name = "Cafe", x = 70, z = 50, w = 30, d = 30, h = 13,
		wall = C(250, 225, 190), wallMat = M.Plaster, trim = C(110, 70, 40), door = C(120, 70, 40),
		awning = { C(40, 140, 80), C(250, 240, 220) },
		sign = "COZY CAFE", signBg = C(90, 55, 35), signFg = C(255, 235, 200), signStroke = C(50, 25, 10), signBorder = C(255, 170, 60),
		font = Enum.Font.FredokaOne, sideRows = { 4.5 }, extras = cafeExtras,
	},
	{
		name = "Apartments", x = 120, z = 50, w = 30, d = 30, h = 24,
		wall = C(175, 85, 65), wallMat = M.Brick, trim = C(245, 245, 240), door = C(40, 70, 130),
		sign = "SUNNY APTS", signW = 12, signBg = C(255, 210, 60), signFg = C(40, 70, 130), signStroke = WHITE,
		frontRows = { 13, 17, 21 }, sideRows = { 4.5, 10.5, 14.5, 18.5 }, extras = apartmentExtras,
	},
	{
		name = "BurgerJoint", x = -120, z = -50, w = 30, d = 30, h = 10,
		wall = C(255, 205, 70), wallMat = M.Plaster, trim = C(220, 40, 40), door = C(220, 40, 40),
		awning = { C(220, 40, 40), WHITE },
		sign = "BURGER JOINT", signY = 13, signU = -4, signW = 18, signBg = C(220, 40, 40), signFg = C(255, 230, 80),
		signStroke = C(110, 20, 10), signBorder = C(255, 220, 60), font = Enum.Font.FredokaOne,
		parapetGap = { 7, 13 }, sideRows = { 4.5 }, extras = burgerExtras,
	},
	{
		name = "Police", x = -70, z = -50, w = 30, d = 30, h = 15,
		wall = C(205, 215, 230), wallMat = M.Concrete, trim = C(30, 55, 130), door = C(30, 55, 130),
		sign = "POLICE", signBg = C(30, 55, 130), signFg = WHITE, signStroke = C(10, 20, 60), signBorder = C(80, 160, 255),
		sideRows = { 4.5, 10.5 }, extras = policeExtras,
	},
	{
		name = "Shop", x = 70, z = -50, w = 30, d = 30, h = 12,
		wall = C(120, 215, 210), wallMat = M.Plaster, trim = WHITE, door = C(255, 90, 160),
		awning = { C(255, 105, 170), WHITE },
		sign = "CORNER SHOP", signBg = C(255, 90, 160), signFg = WHITE, signStroke = C(120, 20, 80), signBorder = C(255, 230, 60),
		font = Enum.Font.FredokaOne, sideRows = { 4.5 }, extras = shopExtras,
	},
	{
		name = "Arcade", x = 120, z = -50, w = 30, d = 30, h = 16,
		wall = C(70, 35, 110), wallMat = M.SmoothPlastic, trim = C(255, 60, 200), trimMat = M.Neon, door = C(30, 20, 50),
		sign = "ARCADE", signBg = C(20, 10, 40), signFg = C(90, 255, 255), signStroke = C(10, 0, 40), signBorder = C(0, 230, 255),
		font = Enum.Font.FredokaOne, frontRows = { 13.7 }, sideRows = { 4.5, 10.5 }, extras = arcadeExtras,
	},
}

-- Team bases ----------------------------------------------------------------
-- Built in a local frame: origin at (±pantryX, 0, 0), -Z faces the field,
-- local X runs across the shop. In that frame (lz = |x| - pantryX):
--   counter lz -2..2, grab zone lz -16..-2 |lx|<9, walk lanes |lx| 8.5..13,
--   spawn lz 5..15 |lx|<5, front opening lz -20..-8 |lx|<16, drop-off lz -38..-22.
-- Kitchen props live at |lx| >= 13.5 (lz > -8) and along the back (lz > 16).

local function buildBase(root: Instance, m: { [string]: any }, team: string)
	local red = team == "Red"
	local s = if red then -1 else 1
	local f = newFolder(root, if red then "PizzaPalace" else "TacoTown")
	local bcf = CF(s * m.pantryX, 0, 0) * ry(if red then -90 else 90)
	local function L(x: number, y: number, z: number): CFrame
		return bcf * CF(x, y, z)
	end

	local wall = if red then C(190, 45, 40) else C(30, 120, 210)
	local wallMat = if red then M.Brick else M.Plaster
	local trim = if red then C(255, 250, 240) else C(255, 210, 40)
	local accent = if red then C(40, 160, 70) else C(0, 190, 180)
	local teamColor = if red then C(220, 40, 40) else C(40, 110, 230)

	-- Shell: back wall, side walls, front pillars, header and roof.
	solid(f, "BackWall", V(40, 14, 0.6), L(0, 7, 18.7), wall, wallMat)
	for _, k in { -1, 1 } do
		solid(f, "SideWall", V(2, 14, 35), L(k * 19, 7, 1.5), wall, wallMat)
		solid(f, "FrontPillar", V(1.8, 14, 1.8), L(k * 17.1, 7, -15.1), accent)
	end
	solid(f, "Header", V(36.4, 5, 1.8), L(0, 11.5, -15.1), wall, wallMat)
	solid(f, "Roof", V(42, 1, 37), L(0, 14.5, 1.5), trim)
	solid(f, "RoofParapet", V(42, 1.5, 0.8), L(0, 15.75, -16.6), trim)
	solid(f, "RoofParapet", V(42, 1.5, 0.8), L(0, 15.75, 19.6), trim)
	for _, k in { -1, 1 } do
		solid(f, "RoofParapet", V(0.8, 1.5, 37), L(k * 20.6, 15.75, 1.5), trim)
	end
	-- Parapet trim: checkerboard (Pizza) or bright tiles (Taco).
	for i = 0, 26 do
		local u = -19.5 + i * 1.5
		if red then
			if i % 2 == 0 then
				deco(f, "Checker", V(1.5, 0.75, 0.1), L(u, 15.375, -17.05), teamColor)
			else
				deco(f, "Checker", V(1.5, 0.75, 0.1), L(u, 16.125, -17.05), teamColor)
			end
		elseif i % 2 == 0 then
			deco(f, "Tile", V(1.4, 1.4, 0.1), L(u, 15.75, -17.05), PICADO[math.floor(i / 2) % #PICADO + 1])
		end
	end

	-- Big storefront sign, awning and window boxes.
	if red then
		sign(f, "BaseSign", V(30, 4, 0.4), L(0, 11.6, -16.4), C(255, 250, 240), "PIZZA PALACE", C(210, 30, 30), C(30, 120, 50), C(255, 80, 60), Enum.Font.FredokaOne)
		awning(f, "BaseAwning", bcf * CF(0, 0, -16), 0, 9, 36, 4, 1.4, { C(220, 30, 30), WHITE }, 3)
	else
		sign(f, "BaseSign", V(30, 4, 0.4), L(0, 11.6, -16.4), C(255, 210, 40), "TACO TOWN", C(30, 90, 200), WHITE, C(0, 230, 210), Enum.Font.FredokaOne)
		awning(f, "BaseAwning", bcf * CF(0, 0, -16), 0, 9, 36, 4, 1.4, { C(30, 110, 220), C(255, 210, 40), C(0, 190, 180), C(255, 80, 160) }, 3)
	end
	-- Windows on the outside of both side walls.
	for _, side in { "left", "right" } do
		local face = faceCF(bcf * CF(0, 0, 1.5), 40, 35, side)
		for _, u in { -10, -2, 6 } do
			window(f, "BaseWindow", face, u, 5, 3.4, 3, trim)
		end
	end

	-- Interior floor: checkerboard tiles.
	flat(f, "ShopFloor", V(36, 0.05, 34.6), L(0, 0.225, 1.3), WHITE, M.Marble)
	local tileColor = if red then C(205, 40, 40) else C(40, 110, 220)
	for i = 0, 8 do
		for j = 0, 8 do
			if (i + j) % 2 == 0 then
				flat(f, "FloorTile", V(4, 0.05, 4), L(-16 + i * 4, 0.25, -14 + j * 4), tileColor)
			end
		end
	end

	-- Pantry counter (contract marker: world-aligned, exact size/position).
	local pantry = solid(f, team .. "Pantry", V(4, 3, 14), CF(s * m.pantryX, 1.5, 0), if red then C(250, 245, 235) else C(240, 248, 255), M.Marble)
	pantry.Position = V(s * m.pantryX, 1.5, 0)
	-- Counter dressing (non-colliding): coloured front stripe, kick plate,
	-- sneeze guard above head height, hanging sign.
	deco(f, "CounterStripe", V(14.2, 0.8, 0.1), L(0, 2.2, -2.06), teamColor)
	deco(f, "CounterKick", V(14.2, 0.5, 0.12), L(0, 0.25, -2.07), C(60, 60, 65))
	glass(f, "CounterDisplay", V(13.6, 1, 0.1), L(0, 1.1, -2.1))
	glass(f, "SneezeGuard", V(14.4, 0.15, 3.4), L(0, 6.9, 0))
	for _, k in { -1, 1 } do
		deco(f, "SneezeGuardPost", V(0.3, 6.9, 0.3), L(k * 7.4, 3.45, 0), STEEL, M.Metal)
		deco(f, "PantrySignChain", V(0.15, 3.4, 0.15), L(k * 5, 12.3, -0.5), C(80, 80, 85), M.Metal)
	end
	sign(f, "PantrySign", V(12, 2.2, 0.4), L(0, 9.5, -0.5), teamColor, "PANTRY", WHITE, C(40, 20, 20), nil, Enum.Font.FredokaOne)

	-- Kitchen along the +lx side wall: oven/grill, fridge, prep counter.
	if red then
		solid(f, "PizzaOven", V(4, 3, 6), L(15.5, 1.5, 11), C(170, 70, 50), M.Brick)
		ball(f, "OvenDome", 4.6, L(15.5, 3.4, 11), C(180, 80, 55), M.Brick, true)
		local mouth = neon(f, "OvenFire", V(0.2, 1.4, 2.4), L(13.1, 3.2, 11), C(255, 130, 30))
		light(mouth, C(255, 140, 50), 14, 1.5)
		local chimney = solid(f, "OvenChimney", V(2, 17.4, 2), L(16, 14.3, 12), C(170, 70, 50), M.Brick)
		solid(f, "ChimneyCap", V(2.6, 0.5, 2.6), L(16, 23.25, 12), C(80, 80, 85), M.Metal)
		local smoke = Instance.new("Smoke")
		smoke.Color = C(230, 230, 230)
		smoke.Opacity = 0.12
		smoke.RiseVelocity = 3
		smoke.Size = 2
		smoke.Parent = chimney
	else
		solid(f, "Grill", V(4, 3, 6), L(15.5, 1.5, 11), STEEL, M.Metal)
		deco(f, "GrillTop", V(4.2, 0.3, 6.2), L(15.5, 3.15, 11), BLACK, M.Metal)
		local glow = neon(f, "GrillGlow", V(0.15, 0.5, 5), L(13.45, 2.4, 11), C(255, 130, 30))
		light(glow, C(255, 140, 50), 12, 1.2)
		deco(f, "GrillHood", V(4.6, 1.6, 6.6), L(15.8, 9.5, 11), STEEL, M.Metal)
		local duct = solid(f, "VentDuct", V(1.6, 10, 1.6), L(16, 15.3, 12), STEEL, M.Metal)
		solid(f, "VentCap", V(2.4, 0.5, 2.4), L(16, 20.5, 12), C(80, 80, 85), M.Metal)
		local smoke = Instance.new("Smoke")
		smoke.Color = C(230, 230, 230)
		smoke.Opacity = 0.1
		smoke.RiseVelocity = 3
		smoke.Size = 2
		smoke.Parent = duct
	end
	solid(f, "Fridge", V(4, 8, 4), L(15.5, 4, 3), STEEL, M.Metal)
	deco(f, "FridgeHandle", V(0.25, 3, 0.3), L(13.4, 4.6, 1.8), C(90, 90, 95), M.Metal)
	deco(f, "FridgeSeam", V(0.1, 0.15, 4), L(13.45, 5.2, 3), C(120, 120, 125), M.Metal)
	solid(f, "PrepCounter", V(4, 3, 7), L(15.5, 1.5, -4), STEEL, M.Metal)
	deco(f, "PrepTop", V(4.2, 0.2, 7.2), L(15.5, 3.1, -4), if red then C(250, 245, 235) else C(255, 210, 40), M.Marble)
	if red then
		vcyl(f, "PizzaOnCounter", 0.2, 3.2, L(15.5, 3.3, -5.5), C(255, 200, 70))
		for k = 0, 2 do
			vcyl(f, "PepperoniOnCounter", 0.25, 0.7, L(15.0 + (k % 2) * 0.9, 3.35, -6.3 + k * 0.8), C(190, 40, 35))
		end
		ball(f, "DoughBall", 1.2, L(15.5, 3.75, -2.6), C(250, 240, 215))
		ball(f, "DoughBall", 1.2, L(15.2, 3.75, -1.3), C(250, 240, 215))
	else
		for k = 0, 2 do
			vcyl(f, "TortillaStack", 0.3, 2.6, L(15.5, 3.35 + k * 0.3, -5.5), C(245, 215, 140))
		end
		vcyl(f, "SalsaBowl", 0.6, 1.6, L(15.4, 3.5, -2.5), C(220, 50, 40))
		vcyl(f, "GuacBowl", 0.6, 1.6, L(15.4, 3.5, -1), C(120, 190, 70))
	end

	-- Kitchen along the -lx side wall: shelves, box stack, sink counter.
	solid(f, "ShelfBack", V(0.4, 8, 10), L(-17.6, 4, 10), WOOD, M.WoodPlanks)
	local jarColors = if red then { C(220, 50, 40), C(90, 170, 70), C(250, 240, 220) } else { C(220, 50, 40), C(120, 190, 70), C(255, 200, 40) }
	for i, y in { 2, 4.5, 7 } do
		solid(f, "Shelf", V(3, 0.3, 10), L(-16, y, 10), WOOD, M.WoodPlanks)
		for k = 0, 2 do
			vcyl(f, "Jar", 1.2, 0.9, L(-16, y + 0.75, 6.5 + k * 3.2), jarColors[(i + k) % 3 + 1], M.Glass)
		end
	end
	for k = 0, 2 do
		solid(f, if red then "PizzaBox" else "ChipBox", V(3, 0.6, 3), L(-15.5, 0.3 + k * 0.6, 0) * ry(k * 7), if red then WHITE else C(255, 200, 60))
	end
	if red then
		deco(f, "PizzaBoxStripe", V(3.05, 0.15, 3.05), L(-15.5, 1.55, 0) * ry(14), C(220, 40, 40))
	end
	solid(f, "SinkCounter", V(4, 3, 7), L(-15.5, 1.5, -4.5), STEEL, M.Metal)
	deco(f, "Faucet", V(0.3, 1.4, 0.3), L(-17, 3.7, -4.5), STEEL, M.Metal)
	deco(f, "FaucetSpout", V(1.2, 0.3, 0.3), L(-16.5, 4.3, -4.5), STEEL, M.Metal)

	-- Back wall: shelf with supplies and the menu board.
	for _, y in { 3, 6 } do
		solid(f, "BackShelf", V(30, 0.3, 1.8), L(0, y, 17.3), WOOD, M.WoodPlanks)
	end
	for k = 0, 5 do
		local col = if k % 2 == 0 then C(240, 230, 200) else (if red then C(200, 60, 50) else C(90, 170, 70))
		solid(f, "Supplies", V(1.6, 1.8, 1.2), L(-12 + k * 4.8, 4.05, 17.3), col)
	end
	if red then
		sign(f, "MenuBoard", V(16, 5, 0.3), L(0, 10.5, 18.2), C(40, 50, 45), "MENU\nPEPPERONI  •  CHEESE\nVEGGIE  •  MARGHERITA", WHITE, C(20, 30, 25), C(255, 200, 60), Enum.Font.FredokaOne)
	else
		sign(f, "MenuBoard", V(16, 5, 0.3), L(0, 10.5, 18.2), C(40, 50, 45), "MENU\nTACOS  •  NACHOS\nBURRITOS  •  CHURROS", WHITE, C(20, 30, 25), C(255, 80, 160), Enum.Font.FredokaOne)
		-- String of chili peppers on the back wall.
		rope(f, "ChiliString", bcf, -17, 8.6, -8, 8.6, 18.2, C(90, 60, 40))
		for k = 0, 5 do
			deco(f, "Chili", V(0.6, 1.4, 0.4), L(-16 + k * 1.5, 7.8, 18.1) * CFrame.Angles(0, 0, math.rad(k % 2 == 0 and 10 or -10)), C(220, 30, 30))
		end
	end

	-- Pendant lamps.
	for _, p in { { -8, 6 }, { 8, 6 }, { 0, -9 } } do
		deco(f, "LampCord", V(0.15, 1.8, 0.15), L(p[1], 13.1, p[2]), BLACK)
		deco(f, "LampShade", V(1.8, 0.7, 1.8), L(p[1], 12, p[2]), accent, M.Metal)
		local bulb = ball(f, "LampBulb", 0.9, L(p[1], 11.4, p[2]), C(255, 240, 200), M.Neon)
		light(bulb, C(255, 225, 180), 18, 1)
	end

	-- Spawn (contract marker).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = team .. "Spawn"
	spawn.Anchored = true
	spawn.Size = V(8, 1, 8)
	spawn.Position = V(s * m.spawnX, 0.5, m.spawnZ)
	spawn.BrickColor = BrickColor.new(if red then "Bright red" else "Bright blue")
	spawn.TeamColor = BrickColor.new(if red then "Bright red" else "Bright blue")
	spawn.Material = M.SmoothPlastic
	spawn.Neutral = false
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = f

	-- Drop-off pad (contract marker) with a glowing border and floor text.
	local drop = deco(f, team .. "Dropoff", V(12, 0.2, 12), CF(s * m.dropoffX, 0.3, m.dropoffZ), teamColor, M.Neon)
	drop.Position = V(s * m.dropoffX, 0.3, m.dropoffZ)
	drop.Transparency = 0.4
	addLabel(drop, Enum.NormalId.Top, "DROP FOOD HERE", WHITE, BLACK, Enum.Font.FredokaOne)
	local dcf = CF(s * m.dropoffX, 0.32, m.dropoffZ)
	for _, k in { -1, 1 } do
		neon(f, "DropoffEdge", V(13, 0.25, 0.6), dcf * CF(0, 0, k * 6.3), WHITE)
		neon(f, "DropoffEdge", V(0.6, 0.25, 13), dcf * CF(k * 6.3, 0, 0), WHITE)
	end

	-- Front porch planters (outside the opening).
	for _, k in { -1, 1 } do
		if red then
			planter(f, L(k * 19.5, 0.2, -18.5) * ry(90), { C(230, 40, 40), C(70, 160, 60), C(230, 40, 40) })
		else
			local pot = L(k * 19.2, 0.2, -18.6)
			vcyl(f, "CactusPot", 1.6, 2.4, pot * CF(0, 0.8, 0), C(205, 100, 60), M.SmoothPlastic, true)
			vcyl(f, "Cactus", 5, 1.4, pot * CF(0, 4.1, 0), C(60, 160, 70), M.Grass)
			deco(f, "CactusArm", V(1.4, 0.8, 0.8), pot * CF(1.1, 3.6, 0), C(60, 160, 70), M.Grass)
			deco(f, "CactusArm", V(0.8, 1.8, 0.8), pot * CF(1.5, 4.5, 0), C(60, 160, 70), M.Grass)
			deco(f, "CactusArm", V(1.4, 0.8, 0.8), pot * CF(-1.1, 4.6, 0), C(60, 160, 70), M.Grass)
			deco(f, "CactusArm", V(0.8, 1.6, 0.8), pot * CF(-1.5, 5.4, 0), C(60, 160, 70), M.Grass)
			ball(f, "CactusFlower", 0.8, pot * CF(0, 6.7, 0), C(255, 80, 160))
		end
	end

	-- Patios on both flanks: tables, umbrellas, string lights / papel picado.
	for _, k in { -1, 1 } do
		local umb = if red then { C(30, 140, 60), WHITE } else { PICADO[(k + 2) % #PICADO + 1], C(255, 210, 40) }
		cafeTable(f, L(k * 28, 0.2, 0), if red then C(220, 40, 40) else C(0, 190, 180), umb)
		cafeTable(f, L(k * 38, 0.2, 9), if red then C(220, 40, 40) else C(0, 190, 180), umb)
		for _, lz in { -3, 6 } do
			solid(f, "PatioPole", V(0.5, 12, 0.5), L(k * 46, 6, lz), LAMP_GREEN, M.Metal)
			bunting(f, if red then "StringLights" else "PapelPicado", bcf, k * 20.6, 13.6, k * 46, 11.8, lz, 9, not red)
		end
	end
	-- Blue: papel picado across the storefront too.
	if not red then
		bunting(f, "PapelPicadoFront", bcf, -20.6, 16.8, 20.6, 16.8, -17.6, 14, true)
	end

	-- Giant rooftop food.
	if red then
		-- Pizza slice standing tip-down: cheese triangle, crust, pepperoni, basil.
		local slice = L(0, 23.6, 6)
		triangle(f, "PizzaCheese", 8, 16, 1.4, slice * FLIP, C(255, 196, 50))
		cyl(f, "PizzaCrust", V(17.6, 2.8, 2.8), slice * CF(0, 8.1, 0), C(205, 130, 60))
		for i, p in { { 0, 4.5, 2.6 }, { -3.2, 1.6, 2.6 }, { 2.4, 0, 2.6 }, { -0.8, -3, 2.0 }, { 3.6, 5, 2.6 }, { -3.8, 5.4, 2.6 } } do
			cyl(f, "Pepperoni" .. i, V(0.25, p[3], p[3]), slice * CF(p[1], p[2], -0.8) * ry(90), C(190, 40, 35))
		end
		for i, p in { { 1.3, 2.4 }, { -1.6, -0.6 }, { 0.6, 6.6 } } do
			deco(f, "Basil" .. i, V(1.1, 0.6, 0.15), slice * CF(p[1], p[2], -0.8) * CFrame.Angles(0, 0, i), C(60, 150, 60))
		end
		deco(f, "PizzaStand", V(0.8, 15, 0.8), L(0, 23, 7.3), C(60, 60, 65), M.Metal)
		local glowPart = neon(f, "PizzaGlow", V(1, 1, 1), slice * CF(0, 2, -3), C(255, 200, 120))
		glowPart.Transparency = 1
		light(glowPart, C(255, 200, 120), 18, 1)
	else
		-- Taco: tortilla shell (two half-disc faces + curved bottom) with fillings.
		local R, y0, tz = 8, 23.6, 6
		local shell = C(245, 200, 95)
		for _, fz in { -2.2, 2.2 } do
			for u = -7.5, 7.5, 1 do
				local hu = math.sqrt(R * R - u * u)
				deco(f, "TacoShell", V(1.05, hu, 0.5), L(u, y0 - hu / 2, tz + fz), shell)
			end
		end
		for i = 0, 9 do
			local th = (i + 0.5) / 10 * math.pi
			local px, py = R * math.cos(th), y0 - R * math.sin(th)
			deco(f, "TacoShellCurve", V(R * math.pi / 10 * 1.1, 0.5, 4.9), L(px, py, tz) * CFrame.Angles(0, 0, math.pi / 2 - th), shell)
		end
		for i = 0, 8 do
			ball(f, "TacoLettuce", 2.4, L(-6.4 + i * 1.6, y0 + 0.5, tz + (i % 2 == 0 and -0.6 or 0.6)), C(90, 200, 70), M.Grass)
		end
		for i, u in { -5, -1.5, 2, 5.5 } do
			deco(f, "TacoTomato", V(1.2, 1.2, 1.2), L(u, y0 + 1.2, tz - 1) * ry(i * 25), C(230, 50, 40))
			deco(f, "TacoCheese", V(2.2, 0.4, 0.4), L(u + 0.8, y0 + 1.5, tz + 0.8) * ry(i * 50), C(255, 215, 50))
		end
		for i = 0, 4 do
			ball(f, "TacoMeat", 1.6, L(-5 + i * 2.5, y0 + 0.2, tz + 0.3), C(130, 70, 40))
		end
		local glowPart = neon(f, "TacoGlow", V(1, 1, 1), L(0, y0 - 4, tz - 5), C(255, 210, 120))
		glowPart.Transparency = 1
		light(glowPart, C(255, 210, 120), 18, 1)
	end

	-- Welcome arch over the base entrance (posts on the sidewalks).
	for _, k in { -1, 1 } do
		solid(f, "GatePost", V(1.6, 16, 1.6), L(k * 23, 8, -36), teamColor)
		local cap = ball(f, "GatePostCap", 2, L(k * 23, 16.6, -36), trim, M.Neon)
		light(cap, trim, 12, 0.8)
	end
	sign(
		f, "GateSign", V(46, 3, 1), L(0, 16.6, -36),
		if red then C(255, 250, 240) else C(255, 210, 40),
		if red then "WELCOME TO PIZZA PALACE" else "¡WELCOME TO TACO TOWN!",
		if red then C(210, 30, 30) else C(30, 90, 200),
		if red then C(30, 120, 50) else WHITE,
		teamColor, Enum.Font.FredokaOne, true
	)

	-- Yard trees.
	for _, k in { -1, 1 } do
		tree(f, (L(k * 52, 0.2, 14)).Position)
		tree(f, (L(k * 87, 0.2, -8)).Position, 0.9)
		tree(f, (L(k * 87, 0.2, 14)).Position, 1.1)
	end
end

-- Streets, park and street furniture ----------------------------------------

local function buildStreets(root: Instance, m: { [string]: any })
	local f = newFolder(root, "Streets")
	local asphalt = C(62, 64, 70)
	local concrete = C(205, 205, 198)
	local paint = C(245, 245, 240)

	solid(f, "MainStreet", V(320, 0.1, 40), CF(0, 0.05, 0), asphalt, M.Asphalt)
	solid(f, "AlleyNorth", V(320, 0.1, 16), CF(0, 0.05, 75), C(80, 80, 86), M.Asphalt)
	solid(f, "AlleySouth", V(320, 0.1, 16), CF(0, 0.05, -75), C(80, 80, 86), M.Asphalt)
	for _, zs in { -1, 1 } do
		local tag = if zs > 0 then "North" else "South"
		solid(f, "Sidewalk" .. tag, V(320, 0.4, 15), CF(0, 0.2, zs * 27.5), concrete, M.Concrete)
		solid(f, "Kerb" .. tag, V(320, 0.5, 0.6), CF(0, 0.25, zs * 20.3), C(235, 235, 230), M.Concrete)
		flat(f, "AlleyLine" .. tag, V(318, 0.04, 0.4), CF(0, 0.12, zs * 75), C(240, 200, 60))
		for _, xs in { -1, 1 } do
			solid(f, "SideStreet", V(20, 0.1, 32), CF(xs * 95, 0.05, zs * 51), asphalt, M.Asphalt)
			solid(f, "CornerPlaza", V(23, 0.3, 32), CF(xs * 148.5, 0.15, zs * 51), C(215, 200, 185), M.Pavement)
			-- Road edge lines (outside the bridge ramps).
			flat(f, "EdgeLine", V(113, 0.04, 0.4), CF(xs * 103.5, 0.12, zs * 18.4), paint)
		end
	end
	-- Centre dashes.
	for _, xs in { -1, 1 } do
		for i = 0, 12 do
			flat(f, "LaneDash", V(4, 0.04, 0.5), CF(xs * (54 + i * 8), 0.12, 0), paint)
		end
	end
	-- Crosswalks at the park edge and at each side street.
	for _, x in { -95, -52, 52, 95 } do
		for k = 0, 7 do
			flat(f, "Crosswalk", V(5, 0.04, 2.2), CF(x, 0.12, -15.4 + k * 4.4), paint)
		end
	end

	-- Street lamps along both sidewalks, arms over the road.
	for _, zs in { -1, 1 } do
		for _, x in { -152, -132, -108, -82, -58, 58, 82, 108, 132, 152 } do
			streetLamp(f, CF(x, 0.4, zs * 22.2) * (if zs > 0 then CF() else ry(180)))
		end
		-- Lamps along the back alleys, against the boundary wall.
		for _, x in { -120, -40, 40, 120 } do
			streetLamp(f, CF(x, 0, zs * 86) * (if zs > 0 then CF() else ry(180)))
		end
	end
	for _, p in { V(-95, 0.4, 23.5), V(95, 0.4, -23.5), V(-150, 0.4, -23.5), V(150, 0.4, 23.5) } do
		hydrant(f, p)
	end
	for _, p in { V(-60, 0.4, 23.6), V(60, 0.4, -23.6), V(-110, 0.4, -23.6), V(110, 0.4, 23.6), V(-30, 0, 85), V(30, 0, -85) } do
		trashCan(f, p)
	end
	-- Dumpsters behind the shops.
	-- Against the outer side of the alley: z ±66..74 is a bot lane (BotService).
	for _, p in { V(-128, 0, 77.5), V(-62, 0, 77.5), V(62, 0, -77.5), V(128, 0, -77.5) } do
		solid(f, "Dumpster", V(5, 3, 2.6), CF(p + V(0, 1.5, 0)), C(40, 110, 70), M.Metal)
		deco(f, "DumpsterLid", V(5.2, 0.3, 2.8), CF(p + V(0, 3.15, 0)), C(30, 80, 50), M.Metal)
	end

	-- Trees: alleys (by the wall) and corner plazas.
	for _, zs in { -1, 1 } do
		for _, x in { -150, -55, -20, 20, 55, 150 } do
			tree(f, V(x, 0, zs * 86.5), 1.1)
		end
		for _, xs in { -1, 1 } do
			tree(f, V(xs * 142, 0.3, zs * 40))
			tree(f, V(xs * 154, 0.3, zs * 62))
			bench(f, CF(xs * 148, 0.3, zs * 52) * ry(if xs > 0 then -90 else 90))
			planter(f, CF(xs * 154, 0.3, zs * 44) * ry(90), { C(255, 90, 140), C(255, 220, 60), C(150, 90, 230) })
		end
	end

	-- Parked cars along the kerbs (outside the main corridor |z| < 12).
	car(f, CF(70, 0.1, 16), C(255, 205, 40), "taxi")
	car(f, CF(128, 0.1, -16) * ry(180), C(220, 50, 50))
	car(f, CF(-104, 0.1, 16), C(60, 170, 160))

	-- Wall billboards above the alleys.
	local ads = {
		{ x = -90, z = 1, text = "PIZZA PARTY TONIGHT!", bg = C(220, 40, 40), fg = C(255, 230, 80) },
		{ x = 90, z = 1, text = "TACO TUESDAY... EVERY DAY!", bg = C(30, 110, 220), fg = C(255, 230, 80) },
		{ x = -90, z = -1, text = "BURGERS: NOW 2X BIGGER!", bg = C(255, 200, 50), fg = C(200, 30, 30) },
		{ x = 90, z = -1, text = "FRESH SUSHI ROLLS", bg = C(30, 30, 35), fg = WHITE },
	}
	for i, ad in ads do
		local cf = CF(ad.x, 15.5, ad.z * 88.6) * (if ad.z > 0 then CF() else ry(180))
		sign(f, "Billboard" .. i, V(34, 7, 0.5), cf, ad.bg, ad.text, ad.fg, BLACK, WHITE, Enum.Font.FredokaOne)
	end
end

local function buildPark(root: Instance, m: { [string]: any })
	local f = newFolder(root, "Park")
	for _, zs in { -1, 1 } do
		local zc = zs * 51
		solid(f, "PlazaPaving", V(36, 0.3, 30), CF(0, 0.15, zc), C(215, 205, 190), M.Pavement)
		-- Fountain.
		local fc = CF(0, 0.3, zs * 52)
		vcyl(f, "FountainBasin", 1.6, 14, fc * CF(0, 0.8, 0), C(225, 225, 220), M.Concrete, true)
		local water = vcyl(f, "FountainWater", 0.2, 12.6, fc * CF(0, 1.5, 0), C(80, 170, 255), M.Glass)
		water.Transparency = 0.2
		vcyl(f, "FountainColumn", 4, 1.6, fc * CF(0, 3.5, 0), C(225, 225, 220), M.Concrete, true)
		vcyl(f, "FountainBowl", 0.6, 5, fc * CF(0, 5.5, 0), C(225, 225, 220), M.Concrete, true)
		local spray = vcyl(f, "FountainSpray", 3, 0.7, fc * CF(0, 7.3, 0), C(200, 235, 255), M.Neon)
		spray.Transparency = 0.5
		light(spray, C(150, 210, 255), 14, 0.6)
		-- Benches around the fountain.
		bench(f, CF(12, 0.3, zs * 52) * ry(90))
		bench(f, CF(-12, 0.3, zs * 52) * ry(-90))
		bench(f, CF(0, 0.3, zs * 62.5) * (if zs > 0 then CF() else ry(180)))
		-- Trees and flower beds.
		for _, xs in { -1, 1 } do
			tree(f, V(xs * 42, 0, zs * 42))
			tree(f, V(xs * 44, 0, zs * 61), 1.2)
			tree(f, V(xs * 26, 0, zs * 64), 0.9)
			planter(f, CF(xs * 21.5, 0, zs * 40) * ry(90), { C(255, 80, 120), C(255, 220, 60), C(255, 140, 40) })
		end
	end

	-- Ice cream cart (north park), lemonade stand (south park).
	local cart = CF(32, 0, 50)
	solid(f, "IceCreamCart", V(5, 3, 2.6), cart * CF(0, 2, 0), WHITE)
	deco(f, "IceCreamCartStripe", V(5.05, 0.6, 2.65), cart * CF(0, 2.6, 0), C(255, 130, 185))
	for _, sx in { -1, 1 } do
		cyl(f, "CartWheel", V(0.5, 1.4, 1.4), cart * CF(sx * 1.6, 0.7, -1.4) * ry(90), BLACK)
	end
	sign(f, "IceCreamSign", V(4.6, 1.2, 0.2), cart * CF(0, 2.1, -1.45), C(255, 130, 185), "ICE CREAM", WHITE, C(160, 40, 100), nil, Enum.Font.FredokaOne)
	deco(f, "CartUmbrellaPole", V(0.25, 4, 0.25), cart * CF(0, 5.5, 0), WHITE)
	vcyl(f, "CartUmbrella", 0.3, 6, cart * CF(0, 7.5, 0), C(255, 130, 185))
	vcyl(f, "CartUmbrellaTop", 0.4, 3, cart * CF(0, 7.8, 0), WHITE)
	vcyl(f, "ConeProp", 2, 0.9, cart * CF(1.6, 4.5, 0), C(220, 170, 100))
	ball(f, "ConeScoop", 1.4, cart * CF(1.6, 5.9, 0), C(255, 170, 200))

	local stand = CF(-32, 0, -50) * ry(180)
	solid(f, "LemonadeStand", V(5, 3, 2.5), stand * CF(0, 1.5, 0), C(255, 225, 70), M.WoodPlanks)
	sign(f, "LemonadeSign", V(4.6, 1.2, 0.2), stand * CF(0, 2.1, -1.35), C(255, 245, 160), "LEMONADE", C(230, 140, 0), WHITE, nil, Enum.Font.FredokaOne)
	for _, sx in { -1, 1 } do
		deco(f, "StandPost", V(0.3, 4, 0.3), stand * CF(sx * 2.3, 5, -1), WHITE)
	end
	awning(f, "LemonadeAwning", stand * CF(0, 0, 1.25), 0, 7.2, 5.2, 2.6, 0.6, { C(255, 210, 40), WHITE }, 1.3)
	for k = 0, 2 do
		ball(f, "Lemon", 0.9, stand * CF(-1 + k, 3.45, 0), C(255, 235, 60))
	end
end

-- Bridge over the main street (names Bridge*/Ramp* are allowed in the corridor).
local function buildBridge(root: Instance)
	local f = newFolder(root, "Bridge")
	local deck = C(190, 190, 200)
	solid(f, "BridgeDeck", V(10, 1, 44), CF(0, 10, 0), deck, M.Concrete)
	for i, p in { V(-20, 5, -20), V(20, 5, -20), V(-20, 5, 20), V(20, 5, 20) } do
		solid(f, "BridgeSupport" .. i, V(2, 10, 2), CF(p), C(120, 120, 130), M.Concrete)
	end
	-- Each ramp is 42 long (local Z) and 44 wide (local X), rising 10 to the deck.
	wedge(f, "RampWest", V(44, 10, 42), CF(-26, 5, 0) * ry(90), C(170, 170, 180), M.Concrete, true)
	wedge(f, "RampEast", V(44, 10, 42), CF(26, 5, 0) * ry(-90), C(170, 170, 180), M.Concrete, true)
	-- Rails (non-colliding) along the deck and ramp edges.
	local rail = C(240, 200, 40)
	local slope = math.atan(10 / 42)
	local rampLen = math.sqrt(42 * 42 + 10 * 10)
	for _, zs in { -1, 1 } do
		deco(f, "BridgeRail", V(10, 0.4, 0.4), CF(0, 13, zs * 22.2), rail, M.Metal)
		deco(f, "BridgeRail", V(rampLen, 0.4, 0.4), CF(-26, 8, zs * 22.2) * CFrame.Angles(0, 0, slope), rail, M.Metal)
		deco(f, "BridgeRail", V(rampLen, 0.4, 0.4), CF(26, 8, zs * 22.2) * CFrame.Angles(0, 0, -slope), rail, M.Metal)
		for _, x in { -40, -30, -20, -10, 0, 10, 20, 30, 40 } do
			local top = 10.5 - math.max(0, math.abs(x) - 5) * 10 / 42
			deco(f, "BridgeRailPost", V(0.3, 3, 0.3), CF(x, top + 1.5, zs * 22.2), rail, M.Metal)
		end
		-- Arch over the deck.
		solid(f, "BridgeArchPost", V(1.5, 12, 1.5), CF(0, 16.5, zs * 21.5), C(220, 40, 40))
	end
	local beam = deco(f, "BridgeArchBeam", V(1.5, 3, 44.5), CF(0, 23.5, 0), C(30, 30, 40))
	addLabel(beam, Enum.NormalId.Right, "DAY OF GLORY", C(255, 220, 60), C(200, 30, 30), Enum.Font.FredokaOne)
	addLabel(beam, Enum.NormalId.Left, "DAY OF GLORY", C(255, 220, 60), C(30, 90, 200), Enum.Font.FredokaOne)
	neon(f, "BridgeArchGlow", V(1.2, 3.6, 45.2), CF(0, 23.5, 0), C(255, 160, 40))
end

-- Pads -------------------------------------------------------------------------

-- Dash pad: flat neon plate with two chevrons pointing along `dir` (±1 on X).
local function dashPad(root: Instance, i: number, x: number, z: number, dir: number)
	local name = "DashPad" .. i
	local cf = CF(x, 0.15, z) * ry(if dir > 0 then -90 else 90) -- local -Z points along dir
	local pad = neon(root, name, V(6, 0.2, 10), cf, C(255, 180, 0))
	pad.Transparency = 0.25
	light(pad, C(255, 190, 60), 10, 0.8)
	for _, tip in { -4.2, -0.2 } do
		for _, sx in { -1, 1 } do
			neon(pad, name .. "Arrow", V(0.9, 0.22, 4.2), cf * CF(sx * 1.48, 0.03, tip + 1.48) * ry(sx * 45), WHITE)
		end
	end
end

-- Jump pad: glowing disc with a faint beam; open sky above (nothing collidable).
local function jumpPad(root: Instance, i: number, x: number, z: number)
	local name = "JumpPad" .. i
	local base = CF(x, 0.25, z)
	local pad = cyl(root, name, V(0.3, 7, 7), base * UP, C(0, 255, 150), M.Neon)
	light(pad, C(0, 255, 150), 16, 1.5)
	billboard(pad, "JUMP!", C(120, 255, 190), 4)
	cyl(pad, name .. "Ring", V(0.2, 8.4, 8.4), CF(x, 0.15, z) * UP, C(40, 40, 50), M.Metal)
	cyl(pad, name .. "Core", V(0.36, 3, 3), base * UP, WHITE, M.Neon)
	local beam = cyl(pad, name .. "Beam", V(10, 6, 6), CF(x, 5.3, z) * UP, C(0, 255, 150), M.Neon)
	beam.Transparency = 0.88
	beam.CastShadow = false
end

-- Lighting ------------------------------------------------------------------------

local function setupLighting()
	Lighting.ClockTime = 14.5
	-- Studio test 2026-10-19: the first values (Brightness 2.5, Ambient 110,
	-- OutdoorAmbient 170, ColorShift_Top 255,235,210, Bloom threshold 0.9)
	-- washed every white/light surface out to glowing white. Toned down.
	Lighting.Brightness = 2
	Lighting.Ambient = C(70, 68, 72)
	Lighting.OutdoorAmbient = C(128, 124, 132)
	Lighting.ColorShift_Top = C(40, 30, 15)
	Lighting.ExposureCompensation = -0.15
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6

	if not Lighting:FindFirstChild("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Name = "Atmosphere"
		atm.Density = 0.25
		atm.Offset = 0.15
		atm.Color = C(200, 215, 235)
		atm.Decay = C(255, 210, 170)
		atm.Glare = 0.2
		atm.Haze = 1
		atm.Parent = Lighting
	end
	if not Lighting:FindFirstChild("Bloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "Bloom"
		bloom.Intensity = 0.35
		bloom.Size = 20
		bloom.Threshold = 1.6 -- only neon/lights bloom, not white walls
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChild("ColorCorrection") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ColorCorrection"
		cc.Saturation = 0.18
		cc.Contrast = 0.06
		cc.Brightness = 0
		cc.TintColor = C(255, 250, 242)
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChild("SunRays") then
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "SunRays"
		rays.Intensity = 0.08
		rays.Spread = 0.6
		rays.Parent = Lighting
	end
end

-- Arena ---------------------------------------------------------------------------

function MapBuildings.buildArena(folder: Instance, m: { [string]: any })
	local wallHeight = m.wallHeight or 20
	local halfLen = m.fieldLength / 2
	local halfWid = m.fieldWidth / 2

	-- 1. Outer boundary walls (brick with a cap).
	local wallColor = C(185, 115, 85)
	local walls = newFolder(folder, "Boundary")
	solid(walls, "WallNorth", V(m.fieldLength, wallHeight, 2), CF(0, wallHeight / 2, halfWid), wallColor, M.Brick)
	solid(walls, "WallSouth", V(m.fieldLength, wallHeight, 2), CF(0, wallHeight / 2, -halfWid), wallColor, M.Brick)
	solid(walls, "WallEast", V(2, wallHeight, m.fieldWidth), CF(halfLen, wallHeight / 2, 0), wallColor, M.Brick)
	solid(walls, "WallWest", V(2, wallHeight, m.fieldWidth), CF(-halfLen, wallHeight / 2, 0), wallColor, M.Brick)
	deco(walls, "WallCap", V(m.fieldLength + 2, 0.8, 2.6), CF(0, wallHeight + 0.4, halfWid), C(225, 215, 200), M.Concrete)
	deco(walls, "WallCap", V(m.fieldLength + 2, 0.8, 2.6), CF(0, wallHeight + 0.4, -halfWid), C(225, 215, 200), M.Concrete)
	deco(walls, "WallCap", V(2.6, 0.8, m.fieldWidth + 2), CF(halfLen, wallHeight + 0.4, 0), C(225, 215, 200), M.Concrete)
	deco(walls, "WallCap", V(2.6, 0.8, m.fieldWidth + 2), CF(-halfLen, wallHeight + 0.4, 0), C(225, 215, 200), M.Concrete)

	-- 2. Ground and team floors.
	solid(folder, "Ground", V(m.fieldLength, 1, m.fieldWidth), CF(0, -0.5, 0), C(105, 175, 85), M.Grass)
	solid(folder, "RedBaseFloor", V(40, 0.2, m.fieldWidth), CF(-halfLen + 20, 0.1, 0), C(200, 95, 80), M.Concrete)
	solid(folder, "BlueBaseFloor", V(40, 0.2, m.fieldWidth), CF(halfLen - 20, 0.1, 0), C(80, 130, 210), M.Concrete)

	buildStreets(folder, m)
	buildPark(folder, m)
	buildBridge(folder)

	-- 3. Team bases.
	buildBase(folder, m, "Red")
	buildBase(folder, m, "Blue")

	-- 4. Shops along the street.
	local shops = newFolder(folder, "Shops")
	for _, b in BUILDINGS do
		buildShop(shops, b)
	end
	-- Stairs up to the Burger Joint roof (roof top y = 10, front face z = -35),
	-- at the west end of the storefront where the parapet has a gap.
	local burger = shops:FindFirstChild("BurgerJoint") :: Instance
	for i = 1, 5 do
		local top = i * 2
		solid(burger, "BurgerJointStep" .. i, V(6, top, 2), CF(-130, top / 2, -23 - i * 2), if i % 2 == 0 then C(255, 205, 60) else C(220, 40, 40), M.WoodPlanks)
	end
	for _, x in { -133.2, -126.8 } do
		deco(burger, "StairRail", V(0.3, 0.3, 13.8), CF(x, 8.25, -29) * CFrame.Angles(math.atan(9.5 / 10), 0, 0), C(60, 60, 65), M.Metal)
	end

	-- 5. Burger spawns (middle pickups) with a glowing ring.
	for i, b in m.burgerSpawns do
		local p = cyl(folder, "BurgerSpawn" .. i, V(0.2, 5, 5), CF(b.x, 0.5, b.z) * UP, C(255, 200, 60), M.Neon)
		p.Transparency = 0.2
		local ring = cyl(folder, "BurgerPadRing" .. i, V(0.15, 7, 7), CF(b.x, 0.45, b.z) * UP, WHITE, M.Neon)
		ring.Transparency = 0.3
		light(ring, C(255, 210, 90), 12, 1)
	end

	-- 6. Pads: dash pads point along the street (both ways on the main street,
	-- toward the centre in the alleys); jump pads sit in the side streets next
	-- to the Bank, Police, Apartments and Arcade.
	local pads = newFolder(folder, "Pads")
	local dash = {
		{ -110, 5, 1 }, { -110, -5, -1 }, { 110, -5, -1 }, { 110, 5, 1 },
		{ -110, 75, 1 }, { 110, 75, -1 }, { -110, -75, 1 }, { 110, -75, -1 },
	}
	for i, d in dash do
		dashPad(pads, i, d[1], d[2], d[3])
	end
	local jump = { { -91, 50 }, { -91, -50 }, { 99, 50 }, { 99, -50 } }
	for i, j in jump do
		jumpPad(pads, i, j[1], j[2])
	end

	-- 7. Lighting.
	setupLighting()
end

return MapBuildings
