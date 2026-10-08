--!strict
-- Pure boundary validation only. State, ownership, proximity and rate checks remain server responsibilities.
local Payloads = require("./Payloads")
local Result = require("./Result")
local Validation = require("../Registry/Validation")
local Game = require("../Config/Game")
local Limits = require("../Config/Validation")
local Schemas = {}
local MAX_INTEGER = Limits.MaxInteger
local MAX_TOKEN_LENGTH = Limits.MaxTokenLength
local MAX_COORDINATE = Limits.MaxCoordinate
-- The built-in accepts plain tables; its inferred metatable generic is overly narrow in this CLI.
local readMetatable = (getmetatable :: unknown) :: (unknown) -> unknown
local actions: { [string]: boolean } = {
	Fire = true,
	Reload = true,
	Ability = true,
	Utility = true,
	Equip = true,
	Purchase = true,
	Dialogue = true,
}
local intentKeys = {
	RequestId = true,
	RoundId = true,
	CharacterGeneration = true,
	Action = true,
	ContentId = true,
	Slot = true,
	Aim = true,
}
local function token(value: unknown): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= MAX_TOKEN_LENGTH
		and string.match(value, "^[%w_%-]+$") ~= nil
end
local function plain(value: unknown): boolean
	return type(value) == "table" and readMetatable(value) == nil
end
function Schemas.inputIntent(value: unknown): Result.Result<Payloads.InputIntent>
	if not plain(value) then
		return Result.failure("InvalidRequest")
	end
	local data = value :: { [string]: unknown }
	local count = 0
	for key in data do
		count += 1
		if count > Limits.MaxIntentFields or not intentKeys[key] then
			return Result.failure("InvalidRequest")
		end
	end
	if
		not token(data.RequestId)
		or not Validation.integer(data.RoundId, 0, MAX_INTEGER)
		or not Validation.integer(data.CharacterGeneration, 1, MAX_INTEGER)
		or type(data.Action) ~= "string"
		or not actions[data.Action]
	then
		return Result.failure("InvalidRequest")
	end
	if data.ContentId ~= nil and not Validation.id(data.ContentId) then
		return Result.failure("InvalidRequest")
	end
	if data.Slot ~= nil and not Validation.integer(data.Slot, 1, Game.GearSlots) then
		return Result.failure("InvalidRequest")
	end
	if data.Aim ~= nil and (not plain(data.Aim) or not Validation.point(data.Aim, MAX_COORDINATE)) then
		return Result.failure("InvalidRequest")
	end
	if
		(data.Action == "Fire" or data.Action == "Reload" or data.Action == "Ability")
		and data.Slot == nil
	then
		return Result.failure("InvalidRequest")
	end
	if data.Action == "Fire" and data.Aim == nil then
		return Result.failure("InvalidRequest")
	end
	if
		(
			data.Action == "Utility"
			or data.Action == "Equip"
			or data.Action == "Purchase"
			or data.Action == "Dialogue"
		) and data.ContentId == nil
	then
		return Result.failure("InvalidRequest")
	end
	-- Shape has been fully validated; authoritative context is supplied separately by the server.
	local copy = table.clone(data)
	if data.Aim ~= nil then
		copy.Aim = table.freeze(table.clone(data.Aim :: Payloads.Point))
	end
	return Result.success((table.freeze(copy) :: unknown) :: Payloads.InputIntent)
end
function Schemas.entityRef(value: unknown): Result.Result<Payloads.EntityRef>
	if not plain(value) then
		return Result.failure("InvalidRequest")
	end
	local data = value :: { [string]: unknown }
	for key in data do
		if key ~= "Id" and key ~= "Generation" and key ~= "RoundId" then
			return Result.failure("InvalidRequest")
		end
	end
	if
		not token(data.Id)
		or not Validation.integer(data.Generation, 1, MAX_INTEGER)
		or not Validation.integer(data.RoundId, 1, MAX_INTEGER)
	then
		return Result.failure("InvalidRequest")
	end
	return Result.success((table.freeze(table.clone(data)) :: unknown) :: Payloads.EntityRef)
end
function Schemas.wheelClock(value: unknown): Result.Result<Payloads.WheelClockSnapshot>
	if not plain(value) then
		return Result.failure("InvalidRequest")
	end
	local data = value :: { [string]: unknown }
	for key in data do
		if key ~= "RemainingSeconds" and key ~= "ProfileReady" and key ~= "PaidSpins" then
			return Result.failure("InvalidRequest")
		end
	end
	local remaining = data.RemainingSeconds
	if
		type(remaining) ~= "number"
		or not Validation.finite(remaining)
		or remaining < 0
		or remaining > Game.FreeSpinCooldownSeconds
		or type(data.ProfileReady) ~= "boolean"
		or not Validation.integer(data.PaidSpins, 0, MAX_INTEGER)
	then
		return Result.failure("InvalidRequest")
	end
	return Result.success((table.freeze(table.clone(data)) :: unknown) :: Payloads.WheelClockSnapshot)
end
return table.freeze(Schemas)
