--!strict
-- Dresses a character model as its Day of Glory character (see Shared/Looks).
-- Works on R15 and R6 rigs, for players and bots alike:
--   * removes the avatar's own accessories and clothing (including layered
--     clothing, which needs Roblox's wrap deformer)
--   * sets body colours (skin, shirt, sleeves, pants, shoes)
--   * welds on simple parts: hair, hats, visor, ears, pizza face, belts
--   * adds a team-coloured armband so teams read at a glance
-- The added parts are cosmetic: massless, no collisions, no touch events,
-- not hit by raycasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Looks = require(ReplicatedStorage.Shared.Looks)

local LookService = {}

local FOLDER = "DayOfGloryLook"

local SKIN_PARTS = { "Head", "LeftHand", "RightHand" }
local SHIRT_PARTS = { "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }
local SLEEVE_PARTS = { "LeftLowerArm", "RightLowerArm" }
local PANTS_PARTS = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }
local SHOE_PARTS = { "LeftFoot", "RightFoot" }

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

local function color(hex: string): Color3
	return Color3.fromHex(hex)
end

local function paint(model: Model, names: { string }, c: Color3)
	for _, name in names do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = c
		end
	end
end

local function strip(model: Model)
	for _, d in model:GetChildren() do
		if
			d:IsA("Accessory")
			or d:IsA("Clothing") -- Shirt, Pants
			or d:IsA("ShirtGraphic")
			or d:IsA("BodyColors")
			or d.Name == FOLDER
		then
			d:Destroy()
		end
	end
	-- Layered clothing lives as WrapLayer objects inside accessory handles;
	-- the accessories are gone now, but clear any stray ones too.
	for _, d in model:GetDescendants() do
		if d:IsA("WrapLayer") then
			d:Destroy()
		end
	end
end

local function cosmetic(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function weldTo(p: BasePart, anchor: BasePart, offset: CFrame)
	p.CFrame = anchor.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = anchor
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
end

local function rotation(r: { number }?): CFrame
	if not r then
		return CFrame.identity
	end
	local x, y, z = math.rad(r[1]), math.rad(r[2]), math.rad(r[3])
	return CFrame.Angles(0, 0, z) * CFrame.Angles(x, 0, 0) * CFrame.Angles(0, y, 0)
end

local function build(spec: Looks.PartSpec, anchor: BasePart): BasePart
	local unit = anchor.Size
	local p: BasePart
	if spec.shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		part.Shape = SHAPES[spec.shape] or Enum.PartType.Block
		p = part
	end
	p.Name = spec.name
	p.Color = color(spec.color)
	p.Material = if spec.material then (Enum.Material :: any)[spec.material] else Enum.Material.SmoothPlastic
	p.Size = Vector3.new(spec.size[1] * unit.X, spec.size[2] * unit.Y, spec.size[3] * unit.Z)
	cosmetic(p)
	-- Roblox characters face -Z (right is +X), so "forward" in the spec is -Z.
	local offset = CFrame.new(spec.offset[1] * unit.X, spec.offset[2] * unit.Y, -spec.offset[3] * unit.Z)
		* rotation(spec.rotate)
	weldTo(p, anchor, offset)
	return p
end

local function first(model: Model, names: { string }): BasePart?
	for _, name in names do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- Dress `model` as `characterId` for `teamColor`. Safe to call again when the
-- character changes: the previous look is removed first.
function LookService.apply(model: Model, characterId: string, teamColor: Color3)
	local look = Looks[characterId]
	if not look then
		warn("LookService: no look for " .. tostring(characterId))
		return
	end
	strip(model)

	local skin = color(look.skin)
	paint(model, SKIN_PARTS, skin)
	paint(model, SHIRT_PARTS, color(look.shirt))
	paint(model, SLEEVE_PARTS, color(look.sleeve or look.skin))
	paint(model, PANTS_PARTS, color(look.pants))
	paint(model, SHOE_PARTS, color(look.shoes))

	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = model

	local head = first(model, { "Head" })
	local torso = first(model, { "UpperTorso", "Torso" })
	for _, spec in look.parts do
		local anchor = if spec.attach == "head" then head else torso
		if anchor then
			build(spec, anchor).Parent = folder
		end
	end

	local arm = first(model, { "LeftUpperArm", "Left Arm" })
	if arm then
		local band = Instance.new("Part")
		band.Name = "TeamBand"
		band.Color = teamColor
		band.Material = Enum.Material.Neon
		band.Size = Vector3.new(arm.Size.X * 1.1, 0.25, arm.Size.Z * 1.1)
		cosmetic(band)
		weldTo(band, arm, CFrame.new(0, arm.Size.Y * 0.2, 0))
		band.Parent = folder
	end
end

return LookService
