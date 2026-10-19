--!strict
-- Tag rules: in your own territory, touching an enemy tags them.

export type Tagger = {
	team: string,
	territory: string?, -- team that owns the ground this actor stands on
	vanished: boolean,
	immune: boolean,
	disabled: boolean, -- frozen or stunned
}

local TagResolution = {}

function TagResolution.canTag(tagger: Tagger, target: Tagger): (boolean, string?)
	if tagger.team == target.team then
		return false, "same team"
	end
	if tagger.disabled then
		return false, "tagger disabled"
	end
	if tagger.territory ~= tagger.team then
		return false, "not in own territory"
	end
	if target.territory ~= tagger.team then
		return false, "target not in tagger territory"
	end
	if target.vanished then
		return false, "target vanished"
	end
	if target.immune then
		return false, "target immune"
	end
	return true, nil
end

-- For a touch between a and b, returns which one is tagged ("a" / "b"), or nil.
function TagResolution.resolveContact(a: Tagger, b: Tagger): ("a" | "b")?
	if TagResolution.canTag(a, b) then
		return "b"
	elseif TagResolution.canTag(b, a) then
		return "a"
	end
	return nil
end

return TagResolution
