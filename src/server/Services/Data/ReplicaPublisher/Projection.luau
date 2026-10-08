--!strict
-- Helpers operate only on detached, schema-validated replica projections.
local Projection = {}

function Projection.copy(value: unknown): unknown
	if type(value) ~= "table" then
		return value
	end
	local copy: { [string | number]: unknown } = {}
	for key, child in value :: { [string | number]: unknown } do
		copy[key] = Projection.copy(child)
	end
	return copy
end

function Projection.equal(first: unknown, second: unknown): boolean
	if type(first) ~= "table" or type(second) ~= "table" then
		return first == second
	end
	local left = first :: { [string | number]: unknown }
	local right = second :: { [string | number]: unknown }
	for key, value in left do
		if not Projection.equal(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

return table.freeze(Projection)
