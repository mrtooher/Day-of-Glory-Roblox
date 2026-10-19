--!strict
-- What each character looks like, taken from The Day of Glory art
-- (Unity: Assets/Resources/Characters/*/hero.png for Kelly, Sol, Vex, Pim;
-- Assets/Sprites/Obstacles/cop.png, chef.png, boss-pizzaman.png and
-- Assets/Sprites/Karts/dog.png for the other four).
--
-- Pure data, no Roblox API calls, so it can be unit tested. LookService
-- turns it into body colours and simple parts welded onto the rig.
--
-- Body colours: skin = head and hands, shirt = torso and upper arms,
-- sleeve = lower arms (defaults to skin), pants = legs, shoes = feet.
--
-- Parts are placed relative to the Head, or to the UpperTorso / Torso for
-- "torso" parts. Offsets and sizes are fractions of that part's size, so they
-- fit any rig:
--   offset = {x, y, z}: x right, y up, z forward (toward the face)
--   size   = {x, y, z}
--   shape  = "Block" | "Ball" | "Cylinder" | "Wedge"
--     (a Cylinder's round axis is its x; a Wedge's slope is in its y/z)
--   rotate = {x, y, z} degrees (optional), applied y first, then x, then z,
--     all around the attach part's axes

export type PartSpec = {
	name: string,
	attach: "head" | "torso",
	shape: "Block" | "Ball" | "Cylinder" | "Wedge",
	color: string,
	offset: { number },
	size: { number },
	rotate: { number }?,
	material: string?,
}

export type Look = {
	skin: string,
	shirt: string,
	sleeve: string?,
	pants: string,
	shoes: string,
	parts: { PartSpec },
}

local Looks: { [string]: Look } = {}

-- KELLY: long black hair swept over one eye, round dark-brown robe, rust belt.
Looks.Kelly = {
	skin = "#f5c8a0",
	shirt = "#3a2a1a",
	sleeve = "#3a2a1a",
	pants = "#3a2a1a",
	shoes = "#0a0604",
	parts = {
		{ name = "HairTop", attach = "head", shape = "Ball", color = "#0a0604", offset = { 0, 0.22, -0.08 }, size = { 1.12, 0.8, 1.12 } },
		{ name = "HairBack", attach = "head", shape = "Block", color = "#0a0604", offset = { 0, -0.35, -0.42 }, size = { 1.0, 1.5, 0.25 } },
		{ name = "HairSweep", attach = "head", shape = "Block", color = "#0a0604", offset = { 0.28, 0.05, 0.5 }, size = { 0.42, 0.7, 0.12 }, rotate = { 0, 0, -12 } },
		{ name = "Belt", attach = "torso", shape = "Block", color = "#a0482a", offset = { 0, -0.45, 0 }, size = { 1.05, 0.12, 1.05 } },
	},
}

-- SOL: red cap with the brim off to the side, orange shirt, cream collar.
Looks.Sol = {
	skin = "#f4d2aa",
	shirt = "#e8962e",
	pants = "#362e26",
	shoes = "#1a120d",
	parts = {
		{ name = "Cap", attach = "head", shape = "Ball", color = "#c44634", offset = { 0, 0.3, 0 }, size = { 1.1, 0.6, 1.1 } },
		{ name = "CapBrim", attach = "head", shape = "Block", color = "#c44634", offset = { -0.55, 0.3, 0.2 }, size = { 0.6, 0.08, 0.45 }, rotate = { 0, 30, 0 } },
		{ name = "Collar", attach = "torso", shape = "Block", color = "#faeed2", offset = { 0, 0.4, 0.52 }, size = { 0.4, 0.18, 0.04 } },
		{ name = "Belt", attach = "torso", shape = "Block", color = "#faeed2", offset = { 0, -0.45, 0 }, size = { 1.05, 0.1, 1.05 } },
	},
}

-- VEX: spiky black hair, black visor shades, purple shirt, lilac trim.
Looks.Vex = {
	skin = "#e8d6c4",
	shirt = "#6c4ea8",
	pants = "#282434",
	shoes = "#1a120e",
	parts = {
		{ name = "SpikeMid", attach = "head", shape = "Wedge", color = "#1c1515", offset = { 0, 0.62, -0.05 }, size = { 0.7, 0.55, 0.35 }, rotate = { 0, 90, 0 } },
		{ name = "SpikeLeft", attach = "head", shape = "Wedge", color = "#1c1515", offset = { -0.38, 0.5, -0.05 }, size = { 0.7, 0.45, 0.35 }, rotate = { 0, 90, 25 } },
		{ name = "SpikeRight", attach = "head", shape = "Wedge", color = "#1c1515", offset = { 0.38, 0.5, -0.05 }, size = { 0.7, 0.45, 0.35 }, rotate = { 0, -90, -25 } },
		{ name = "Visor", attach = "head", shape = "Block", color = "#1c1a20", offset = { 0, 0.08, 0.5 }, size = { 0.9, 0.2, 0.1 }, material = "SmoothPlastic" },
		{ name = "VisorShine", attach = "head", shape = "Block", color = "#d0c4ec", offset = { 0, 0.08, 0.56 }, size = { 0.7, 0.03, 0.02 } },
		{ name = "Collar", attach = "torso", shape = "Block", color = "#d0c4ec", offset = { 0, 0.4, 0.52 }, size = { 0.4, 0.18, 0.04 } },
		{ name = "Belt", attach = "torso", shape = "Block", color = "#d0c4ec", offset = { 0, -0.45, 0 }, size = { 1.05, 0.1, 1.05 } },
	},
}

-- PIM: dark hair in two puffs, green shirt, yellow collar and belt.
Looks.Pim = {
	skin = "#96623e",
	shirt = "#3f8c56",
	pants = "#28342e",
	shoes = "#1a120d",
	parts = {
		{ name = "HairTop", attach = "head", shape = "Ball", color = "#1b130e", offset = { 0, 0.3, -0.05 }, size = { 1.08, 0.6, 1.08 } },
		{ name = "PuffLeft", attach = "head", shape = "Ball", color = "#1b130e", offset = { -0.45, 0.42, 0 }, size = { 0.5, 0.5, 0.5 } },
		{ name = "PuffRight", attach = "head", shape = "Ball", color = "#1b130e", offset = { 0.45, 0.42, 0 }, size = { 0.5, 0.5, 0.5 } },
		{ name = "Collar", attach = "torso", shape = "Block", color = "#f5de78", offset = { 0, 0.4, 0.52 }, size = { 0.4, 0.18, 0.04 } },
		{ name = "Belt", attach = "torso", shape = "Block", color = "#f5de78", offset = { 0, -0.45, 0 }, size = { 1.05, 0.1, 1.05 } },
	},
}

-- COP: navy uniform, navy peaked cap with a gold badge, brown belt.
Looks.Cop = {
	skin = "#f2a07e",
	shirt = "#242b43",
	sleeve = "#242b43",
	pants = "#242b43",
	shoes = "#3a2414",
	parts = {
		{ name = "CapCrown", attach = "head", shape = "Cylinder", color = "#303f60", offset = { 0, 0.5, 0 }, size = { 0.3, 1.15, 1.15 }, rotate = { 0, 0, 90 } },
		{ name = "CapBrim", attach = "head", shape = "Block", color = "#1a1f30", offset = { 0, 0.38, 0.5 }, size = { 0.8, 0.06, 0.35 } },
		{ name = "CapBadge", attach = "head", shape = "Block", color = "#e59f32", offset = { 0, 0.5, 0.58 }, size = { 0.2, 0.2, 0.04 } },
		{ name = "ChestBadge", attach = "torso", shape = "Block", color = "#e59f32", offset = { -0.25, 0.2, 0.52 }, size = { 0.18, 0.2, 0.04 } },
		{ name = "Belt", attach = "torso", shape = "Block", color = "#5a3a1e", offset = { 0, -0.45, 0 }, size = { 1.05, 0.14, 1.05 } },
		{ name = "Buckle", attach = "torso", shape = "Block", color = "#e59f32", offset = { 0, -0.45, 0.53 }, size = { 0.18, 0.12, 0.04 } },
	},
}

-- DOG: brown fur all over, floppy darker ears, cream muzzle, black nose,
-- pink tongue.
Looks.Dog = {
	skin = "#8a5a32",
	shirt = "#8a5a32",
	sleeve = "#8a5a32",
	pants = "#8a5a32",
	shoes = "#6e4424",
	parts = {
		{ name = "EarLeft", attach = "head", shape = "Block", color = "#6e4424", offset = { -0.58, -0.05, 0 }, size = { 0.15, 0.8, 0.45 }, rotate = { 0, 0, -10 } },
		{ name = "EarRight", attach = "head", shape = "Block", color = "#6e4424", offset = { 0.58, -0.05, 0 }, size = { 0.15, 0.8, 0.45 }, rotate = { 0, 0, 10 } },
		{ name = "Muzzle", attach = "head", shape = "Ball", color = "#f0dcc0", offset = { 0, -0.15, 0.5 }, size = { 0.55, 0.42, 0.45 } },
		{ name = "Nose", attach = "head", shape = "Ball", color = "#1a1010", offset = { 0, -0.05, 0.74 }, size = { 0.2, 0.15, 0.12 } },
		{ name = "Tongue", attach = "head", shape = "Block", color = "#e8708a", offset = { 0, -0.38, 0.62 }, size = { 0.14, 0.22, 0.05 } },
	},
}

-- PIZZA MAN: a pepperoni pizza for a face, white apron with a red pocket.
Looks.PizzaMan = {
	skin = "#f0b48a",
	shirt = "#f7f3ea",
	sleeve = "#f0b48a",
	pants = "#f7f3ea",
	shoes = "#f7f3ea",
	parts = {
		{ name = "PizzaCrust", attach = "head", shape = "Cylinder", color = "#d8963a", offset = { 0, 0, 0.5 }, size = { 0.12, 1.25, 1.25 }, rotate = { 0, 90, 0 } },
		{ name = "PizzaCheese", attach = "head", shape = "Cylinder", color = "#f6c34a", offset = { 0, 0, 0.57 }, size = { 0.04, 1.05, 1.05 }, rotate = { 0, 90, 0 } },
		{ name = "Pepperoni1", attach = "head", shape = "Cylinder", color = "#d43c2c", offset = { -0.28, 0.25, 0.6 }, size = { 0.03, 0.22, 0.22 }, rotate = { 0, 90, 0 } },
		{ name = "Pepperoni2", attach = "head", shape = "Cylinder", color = "#d43c2c", offset = { 0.3, 0.22, 0.6 }, size = { 0.03, 0.22, 0.22 }, rotate = { 0, 90, 0 } },
		{ name = "Pepperoni3", attach = "head", shape = "Cylinder", color = "#d43c2c", offset = { 0.05, -0.3, 0.6 }, size = { 0.03, 0.22, 0.22 }, rotate = { 0, 90, 0 } },
		{ name = "Pocket", attach = "torso", shape = "Block", color = "#d43c2c", offset = { 0, 0, 0.52 }, size = { 0.3, 0.25, 0.04 } },
	},
}

-- COOK: white chef's jacket and tall white hat, red neckerchief, black
-- moustache, brown shoes.
Looks.Cook = {
	skin = "#f2c69c",
	shirt = "#ffffff",
	sleeve = "#ffffff",
	pants = "#ffffff",
	shoes = "#5a3420",
	parts = {
		{ name = "HatBand", attach = "head", shape = "Cylinder", color = "#ffffff", offset = { 0, 0.55, 0 }, size = { 0.35, 1.05, 1.05 }, rotate = { 0, 0, 90 } },
		{ name = "HatPuff", attach = "head", shape = "Ball", color = "#ffffff", offset = { 0, 1.0, 0 }, size = { 1.3, 0.75, 1.3 } },
		{ name = "Moustache", attach = "head", shape = "Block", color = "#1a1210", offset = { 0, -0.15, 0.52 }, size = { 0.6, 0.12, 0.08 } },
		{ name = "Neckerchief", attach = "torso", shape = "Block", color = "#c8202a", offset = { 0, 0.4, 0.52 }, size = { 0.45, 0.2, 0.05 } },
	},
}

return Looks
