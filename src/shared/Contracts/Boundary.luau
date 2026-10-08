--!strict
-- Shared pure shape checks. Never read untrusted metatable fields or run recursive generic copying.
local Validation = require("../Registry/Validation")
local Limits = require("../Config/Validation")
local Result = require("./Result")
local readMetatable = (getmetatable :: unknown) :: (unknown) -> unknown
export type Check = (unknown) -> boolean
export type Fields = { [string]: Check }
local Boundary = {}

function Boundary.plain(value: unknown): boolean
	return type(value) == "table" and readMetatable(value) == nil
end

function Boundary.token(value: unknown): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= Limits.MaxTokenLength
		and string.match(value, "^[%w_%-]+$") ~= nil
end

function Boundary.id(value: unknown): boolean
	return Validation.id(value)
end

function Boundary.positiveInteger(value: unknown): boolean
	return Validation.integer(value, 1, Limits.MaxInteger)
end

function Boundary.point(value: unknown): boolean
	return Boundary.plain(value) and Validation.point(value, Limits.MaxCoordinate)
end

function Boundary.direction(value: unknown): boolean
	if not Boundary.point(value) then
		return false
	end
	local point = value :: { X: number, Y: number, Z: number }
	local magnitudeSquared = point.X * point.X + point.Y * point.Y + point.Z * point.Z
	return math.abs(magnitudeSquared - 1) <= Limits.DirectionMagnitudeTolerance
end

function Boundary.optional(check: Check): Check
	return function(value: unknown): boolean
		return value == nil or check(value)
	end
end

function Boundary.oneOf(values: { string }): Check
	local allowed: { [string]: boolean } = {}
	for _, value in values do
		allowed[value] = true
	end
	return function(value: unknown): boolean
		return type(value) == "string" and allowed[value] == true
	end
end

--[=[ Validates exact fields before making an owned immutable copy. Nested fields here are Points only. ]=]
function Boundary.record<T>(value: unknown, fields: Fields, extra: Check?, maxFields: number?): Result.Result<T>
	if not Boundary.plain(value) then
		return Result.failure("InvalidRequest")
	end
	local data = value :: { [string]: unknown }
	local count = 0
	for key in data do
		count += 1
		if count > (maxFields or Limits.MaxCommandFields) or fields[key] == nil then
			return Result.failure("InvalidRequest")
		end
	end
	for key, check in fields do
		if not check(data[key]) then
			return Result.failure("InvalidRequest")
		end
	end
	if extra and not extra(data) then
		return Result.failure("InvalidRequest")
	end
	local copy = table.clone(data)
	for key, field in copy do
		if type(field) == "table" then
			copy[key] = table.freeze(table.clone(field :: { [string]: unknown }))
		end
	end
	return Result.success((table.freeze(copy) :: unknown) :: T)
end

return table.freeze(Boundary)
