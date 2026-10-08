--!strict
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Validation = {}
local MAX_INTEGER = 9007199254740991

function Validation.finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end
function Validation.point(point: Payloads.Point): boolean
	return type(point) == "table"
		and type(point.X) == "number"
		and Validation.finite(point.X)
		and type(point.Y) == "number"
		and Validation.finite(point.Y)
		and type(point.Z) == "number"
		and Validation.finite(point.Z)
end
function Validation.ref(ref: Payloads.EntityRef): boolean
	return type(ref) == "table"
		and type(ref.Id) == "string"
		and #ref.Id > 0
		and #ref.Id <= 128
		and type(ref.Generation) == "number"
		and Validation.finite(ref.Generation)
		and ref.Generation >= 1
		and ref.Generation <= MAX_INTEGER
		and ref.Generation % 1 == 0
		and type(ref.RoundId) == "number"
		and Validation.finite(ref.RoundId)
		and ref.RoundId >= 1
		and ref.RoundId <= MAX_INTEGER
		and ref.RoundId % 1 == 0
end
function Validation.distance(first: Payloads.Point, second: Payloads.Point): number
	return math.sqrt((first.X - second.X) ^ 2 + (first.Y - second.Y) ^ 2 + (first.Z - second.Z) ^ 2)
end
function Validation.unit(point: Payloads.Point, tolerance: number): boolean
	local length = math.sqrt(point.X ^ 2 + point.Y ^ 2 + point.Z ^ 2)
	return Validation.finite(length) and math.abs(length - 1) <= tolerance
end
function Validation.sync<T>(callback: () -> T): (boolean, T?)
	local thread = coroutine.create(callback)
	local ok, value = coroutine.resume(thread)
	if not ok or coroutine.status(thread) ~= "dead" then
		pcall(coroutine.close, thread)
		return false, nil
	end
	return true, value
end
return table.freeze(Validation)
