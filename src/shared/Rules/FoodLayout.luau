--!strict
-- Where each team's food sits: some on the base counter, some on rooftop
-- pedestals (Arena parts named <Team>RoofFood<k>). Pure data, unit tested.

local FoodLayout = {}

export type Layout = { base: { string }, roof: { string } }
export type Slot = {
	foodType: string,
	kind: "base" | "roof",
	index: number, -- position on the counter (base) or k of <Team>RoofFood<k> (roof)
	marker: string?, -- roof pedestal part name
}

function FoodLayout.slots(layout: Layout, team: string): { Slot }
	local list: { Slot } = {}
	for i, f in layout.base do
		table.insert(list, { foodType = f, kind = "base", index = i })
	end
	for k, f in layout.roof do
		table.insert(list, { foodType = f, kind = "roof", index = k, marker = team .. "RoofFood" .. k })
	end
	return list
end

-- Every food type appears exactly once across base + roof.
function FoodLayout.validate(layout: Layout, foodTypes: { string }): (boolean, string?)
	local count: { [string]: number } = {}
	for _, f in layout.base do
		count[f] = (count[f] or 0) + 1
	end
	for _, f in layout.roof do
		count[f] = (count[f] or 0) + 1
	end
	for _, f in foodTypes do
		if count[f] ~= 1 then
			return false, f .. " placed " .. tostring(count[f] or 0) .. " times"
		end
		count[f] = nil
	end
	local extra = next(count)
	if extra then
		return false, "unknown food " .. tostring(extra)
	end
	return true, nil
end

return FoodLayout
