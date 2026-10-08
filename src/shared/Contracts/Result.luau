--!strict
export type ErrorCode =
	"InvalidRequest"
	| "UnknownId"
	| "WrongState"
	| "NotReady"
	| "NotOwned"
	| "InsufficientFunds"
	| "LimitReached"
	| "Cooldown"
	| "RateLimited"
	| "StaleRound"
	| "Unavailable"
export type Result<T> = { Ok: true, Value: T } | { Ok: false, Code: ErrorCode }

local Result = {}
local errorCodes: { [string]: boolean } = table.freeze({
	InvalidRequest = true,
	UnknownId = true,
	WrongState = true,
	NotReady = true,
	NotOwned = true,
	InsufficientFunds = true,
	LimitReached = true,
	Cooldown = true,
	RateLimited = true,
	StaleRound = true,
	Unavailable = true,
})

function Result.isErrorCode(value: unknown): boolean
	return type(value) == "string" and errorCodes[value] == true
end

--[=[ Returns an explicit error without exposing internal diagnostics. ]=]
function Result.failure(code: ErrorCode): { Ok: false, Code: ErrorCode }
	local result: { Ok: false, Code: ErrorCode } = { Ok = false, Code = code }
	return table.freeze(result)
end

function Result.success<T>(value: T): { Ok: true, Value: T }
	local result: { Ok: true, Value: T } = { Ok = true, Value = value }
	return table.freeze(result)
end

return table.freeze(Result)
