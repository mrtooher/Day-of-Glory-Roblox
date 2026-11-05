--!strict
-- Where the POWER button goes on touch screens (Jim 2026-11-04: it sat on top
-- of Roblox's jump button). Pure screen math, no Roblox API calls:
-- PowerButtons reads the jump button's absolute rect and places POWER above
-- it, centred, clamped on screen. If there's no room above, it goes to the
-- left of the jump button instead.

export type Rect = { x: number, y: number, w: number, h: number }
export type Size = { x: number, y: number }

local PowerLayout = {}

local MARGIN = 8 -- keep this far from the screen edges

-- Top-left (x, y) for the POWER button, or nil when there is no jump button.
function PowerLayout.aboveJump(jump: Rect?, screen: Size, button: Size, gap: number): (number?, number?)
	if jump == nil then
		return nil, nil
	end
	local function clampX(x: number): number
		return math.clamp(x, MARGIN, math.max(MARGIN, screen.x - MARGIN - button.x))
	end
	local y = jump.y - gap - button.y
	if y >= MARGIN then
		return clampX(jump.x + jump.w / 2 - button.x / 2), y
	end
	-- No room above: left of the jump button, bottoms aligned.
	local x = jump.x - gap - button.x
	local ly = math.clamp(jump.y + jump.h - button.y, MARGIN, math.max(MARGIN, screen.y - MARGIN - button.y))
	return math.max(MARGIN, x), ly
end

return PowerLayout
