--!strict
-- Pure validation primitives shared by registries and future canonical intent schemas.
local Validation = {}
function Validation.finite(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Validation.integer(value: unknown, minimum: number, maximum: number): boolean
	return type(value) == "number"
		and Validation.finite(value)
		and value % 1 == 0
		and value >= minimum
		and value <= maximum
end
--[=[ Studio simulated players use negative IDs. Callers must also resolve a current Player. ]=]
function Validation.playerId(value: unknown, maximum: number): boolean
	return Validation.integer(value, -maximum, maximum) and value ~= 0
end
function Validation.id(value: unknown): boolean
	return type(value) == "string" and #value <= 64 and string.match(value, "^[a-z][a-z0-9_]*$") ~= nil
end
function Validation.point(value: unknown, limit: number): boolean
	if type(value) ~= "table" or not Validation.finite(limit) or limit <= 0 then
		return false
	end
	local point = value :: { [string]: unknown }
	for _, axis in { "X", "Y", "Z" } do
		local coordinate = point[axis]
		if
			type(coordinate) ~= "number"
			or not Validation.finite(coordinate)
			or math.abs(coordinate) > limit
		then
			return false
		end
	end
	for key in point do
		if key ~= "X" and key ~= "Y" and key ~= "Z" then
			return false
		end
	end
	return true
end
return table.freeze(Validation)
