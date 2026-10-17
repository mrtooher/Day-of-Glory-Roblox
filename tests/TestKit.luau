--!strict
-- Minimal test helper for Lune. Each spec file returns function(t) ... end.

local TestKit = {}

export type T = {
	test: (name: string, fn: () -> ()) -> (),
	eq: (actual: any, expected: any, msg: string?) -> (),
	truthy: (value: any, msg: string?) -> (),
	falsy: (value: any, msg: string?) -> (),
	near: (actual: number, expected: number, eps: number?, msg: string?) -> (),
	throws: (fn: () -> (), msg: string?) -> (),
}

local function fmt(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function TestKit.new(suiteName: string)
	local results = { passed = 0, failed = 0, failures = {} :: { string } }

	local t = {} :: any

	function t.test(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			results.passed += 1
		else
			results.failed += 1
			table.insert(results.failures, string.format("%s > %s: %s", suiteName, name, tostring(err)))
		end
	end

	function t.eq(actual: any, expected: any, msg: string?)
		if actual ~= expected then
			error(string.format("%sexpected %s, got %s", if msg then msg .. ": " else "", fmt(expected), fmt(actual)), 2)
		end
	end

	function t.truthy(value: any, msg: string?)
		if not value then
			error(string.format("%sexpected truthy, got %s", if msg then msg .. ": " else "", fmt(value)), 2)
		end
	end

	function t.falsy(value: any, msg: string?)
		if value then
			error(string.format("%sexpected falsy, got %s", if msg then msg .. ": " else "", fmt(value)), 2)
		end
	end

	function t.near(actual: number, expected: number, eps: number?, msg: string?)
		if math.abs(actual - expected) > (eps or 1e-6) then
			error(string.format("%sexpected ~%s, got %s", if msg then msg .. ": " else "", fmt(expected), fmt(actual)), 2)
		end
	end

	function t.throws(fn: () -> (), msg: string?)
		local ok = pcall(fn)
		if ok then
			error((msg or "expected error") .. ", but call succeeded", 2)
		end
	end

	return t :: T, results
end

return TestKit
