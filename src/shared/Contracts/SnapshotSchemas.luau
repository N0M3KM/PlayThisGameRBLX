--!strict
-- Current draft replica projections only; no session, receipt journal or arbitrary private fields.
local Payloads = require("./Payloads")
local Result = require("./Result")
local Boundary = require("./Boundary")
local Validation = require("../Registry/Validation")
local Limits = require("../Config/Validation")
local Game = require("../Config/Game")
local SnapshotSchemas = {}
local function nonnegative(value: unknown): boolean
	return Validation.integer(value, 0, Limits.MaxInteger)
end
local function timestamp(value: unknown): boolean
	return type(value) == "number" and Validation.finite(value) and value >= 0
end
local function cooldown(value: unknown): boolean
	return timestamp(value) and (value :: number) <= Game.FreeSpinCooldownSeconds
end

function SnapshotSchemas.match(value: unknown): Result.Result<Payloads.MatchSnapshot>
	return Boundary.record(value, {
		ContractVersion = function(version: unknown): boolean
			return version == Payloads.Version
		end,
		Revision = nonnegative,
		RoundId = nonnegative,
		State = Boundary.oneOf({
			"Idle",
			"Intermission",
			"Voting",
			"Loading",
			"Teleport",
			"PreRound",
			"Active",
			"Resolution",
			"Results",
		}),
		EndsAt = Boundary.optional(timestamp),
		MapId = Boundary.optional(Boundary.id),
		ScenarioId = Boundary.optional(Boundary.id),
	}, function(candidate: unknown): boolean
		local data = candidate :: { State: string, RoundId: number, EndsAt: number? }
		return if data.State == "Idle" then data.EndsAt == nil else data.RoundId > 0 and data.EndsAt ~= nil
	end)
end

local function ids(value: unknown): { string }?
	if not Boundary.plain(value) then
		return nil
	end
	local entries = value :: { [unknown]: unknown }
	local count, maximum = 0, 0
	local seen: { [string]: boolean } = {}
	for index, id in entries do
		count += 1
		if
			count > Limits.MaxSnapshotDefinitions
			or not Validation.integer(index, 1, Limits.MaxSnapshotDefinitions)
			or not Validation.id(id)
		then
			return nil
		end
		local name = id :: string
		if seen[name] then
			return nil
		end
		seen[name] = true
		maximum = math.max(maximum, index :: number)
	end
	if maximum ~= count then
		return nil
	end
	local copy: { string } = {}
	for index = 1, count do
		copy[index] = entries[index] :: string
	end
	return table.freeze(copy)
end

local function utilities(value: unknown): { [string]: number }?
	if not Boundary.plain(value) then
		return nil
	end
	local entries = value :: { [unknown]: unknown }
	local count = 0
	local copy: { [string]: number } = {}
	for id, quantity in entries do
		count += 1
		if
			count > Limits.MaxSnapshotDefinitions
			or not Validation.id(id)
			or not Validation.integer(quantity, 0, Game.UtilityCap)
		then
			return nil
		end
		copy[id :: string] = quantity :: number
	end
	return table.freeze(copy)
end

function SnapshotSchemas.inventory(value: unknown): Result.Result<Payloads.Inventory>
	if not Boundary.plain(value) then
		return Result.failure("InvalidRequest")
	end
	local data = value :: { [string]: unknown }
	for key in data do
		if key ~= "Gears" and key ~= "Utilities" and key ~= "Armours" and key ~= "Classes" then
			return Result.failure("InvalidRequest")
		end
	end
	local gears, items, armours, classes =
		ids(data.Gears), utilities(data.Utilities), ids(data.Armours), ids(data.Classes)
	if not gears or not items or not armours or not classes then
		return Result.failure("InvalidRequest")
	end
	return Result.success(
		table.freeze({ Gears = gears, Utilities = items, Armours = armours, Classes = classes })
	)
end

function SnapshotSchemas.player(value: unknown): Result.Result<Payloads.PlayerDataSnapshot>
	-- Inventory is recursively validated and copied separately; no generic recursive untrusted copy.
	local envelope: Result.Result<Payloads.PlayerDataSnapshot> = Boundary.record(value, {
		SchemaVersion = Boundary.positiveInteger,
		UserId = function(userId: unknown): boolean
			return Validation.playerId(userId, Limits.MaxInteger)
		end,
		Revision = nonnegative,
		Coins = function(coins: unknown): boolean
			return timestamp(coins) and (coins :: number) <= Limits.MaxInteger
		end,
		TotalXP = function(xp: unknown): boolean
			return timestamp(xp) and (xp :: number) <= Limits.MaxInteger
		end,
		Level = Boundary.positiveInteger,
		Inventory = function(inventory: unknown): boolean
			return SnapshotSchemas.inventory(inventory).Ok
		end,
		FreeSpinRemainingSeconds = cooldown,
		PaidSpins = nonnegative,
	}, nil, Limits.MaxSnapshotFields)
	if not envelope.Ok then
		return envelope
	end
	local inventory = SnapshotSchemas.inventory(envelope.Value.Inventory)
	assert(inventory.Ok, "Validated inventory must remain valid")
	local copy = table.clone(envelope.Value)
	copy.Inventory = inventory.Value
	return Result.success(table.freeze(copy))
end

--[=[ Public ranked board facts only; bounded dense entries and unique identities. ]=]
function SnapshotSchemas.board(value: unknown): Result.Result<Payloads.BoardSnapshot>
	if not Boundary.plain(value) then
		return Result.failure("InvalidRequest")
	end
	local data = value :: { [string]: unknown }
	local fields = 0
	for key in data do
		fields += 1
		if key ~= "Id" and key ~= "Entries" and key ~= "UpdatedAt" then
			return Result.failure("InvalidRequest")
		end
	end
	if
		fields ~= 3
		or not Boundary.id(data.Id)
		or not timestamp(data.UpdatedAt)
		or not Boundary.plain(data.Entries)
	then
		return Result.failure("InvalidRequest")
	end
	local entries = data.Entries :: { [unknown]: unknown }
	local count, maximum = 0, 0
	for index in entries do
		count += 1
		if count > Limits.MaxBoardEntries or not Validation.integer(index, 1, Limits.MaxBoardEntries) then
			return Result.failure("InvalidRequest")
		end
		maximum = math.max(maximum, index :: number)
	end
	if count ~= maximum then
		return Result.failure("InvalidRequest")
	end
	local seen: { [number]: boolean } = {}
	local copy: { Payloads.BoardEntry } = {}
	for index = 1, count do
		local checked: Result.Result<Payloads.BoardEntry> = Boundary.record(entries[index], {
			UserId = function(id: unknown): boolean
				return Validation.playerId(id, Limits.MaxInteger)
			end,
			Value = function(amount: unknown): boolean
				return timestamp(amount) and (amount :: number) <= Limits.MaxInteger
			end,
		})
		if not checked.Ok or seen[checked.Value.UserId] then
			return Result.failure("InvalidRequest")
		end
		seen[checked.Value.UserId] = true
		copy[index] = checked.Value
	end
	return Result.success(table.freeze({
		Id = data.Id :: string,
		UpdatedAt = data.UpdatedAt :: number,
		Entries = table.freeze(copy),
	}))
end

return table.freeze(SnapshotSchemas)
