--!strict
-- Which team owns a point on the field. The field is split along X at
-- centerX; a strip of +/- neutralHalfWidth around the line belongs to nobody.

export type Layout = {
	centerX: number,
	neutralHalfWidth: number,
	negativeSideTeam: string,
	positiveSideTeam: string,
}

local Territory = {}

function Territory.ownerAt(x: number, layout: Layout): string?
	local offset = x - layout.centerX
	if math.abs(offset) <= layout.neutralHalfWidth then
		return nil
	end
	return if offset < 0 then layout.negativeSideTeam else layout.positiveSideTeam
end

return Territory
