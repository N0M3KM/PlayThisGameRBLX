--!strict
local Result = require("../../Contracts/Result")
local Validation = require("../../Registry/Validation")
local Limits = require("../../Config/Validation")

export type Snapshot = {
	RoundId: number,
	Choices: { string },
	Counts: { [string]: number },
	Deadline: number?,
}
export type Ledger = {
	open: (self: Ledger, roundId: number, choices: { string }, deadline: number) -> Result.Result<boolean>,
	cast: (
		self: Ledger,
		userId: number,
		roundId: number,
		mapId: string,
		now: number
	) -> Result.Result<boolean>,
	removePlayer: (self: Ledger, userId: number) -> Result.Result<boolean>,
	resolve: (self: Ledger, roundId: number, now: number) -> Result.Result<string>,
	close: (self: Ledger) -> (),
	snapshot: (self: Ledger) -> Snapshot,
}
type State = {
	RoundId: number,
	Choices: { string },
	Counts: { [string]: number },
	Votes: { [number]: string },
	Deadline: number?,
	Revision: number,
	Random: (number, number) -> number,
}
local VoteLedger = {}
local readMetatable = (getmetatable :: unknown) :: (unknown) -> unknown

local function validIdentity(value: number): boolean
	return Validation.integer(value, 1, Limits.MaxInteger)
end

local function validTime(value: number): boolean
	return Validation.finite(value) and value >= 0
end

local function copyChoices(choices: { string }): { string }?
	if type(choices) ~= "table" or readMetatable(choices) ~= nil then
		return nil
	end
	local length = #choices
	if length == 0 or length > Limits.MaxSnapshotDefinitions then
		return nil
	end
	local seen: { [string]: boolean } = {}
	local count = 0
	for index, mapId in choices do
		if not Validation.integer(index, 1, length) or not Validation.id(mapId) or seen[mapId] then
			return nil
		end
		seen[mapId] = true
		count += 1
	end
	if count ~= length then
		return nil
	end
	return table.freeze(table.clone(choices))
end

local function open(
	state: State,
	roundId: number,
	choices: { string },
	deadline: number
): Result.Result<boolean>
	if not validIdentity(roundId) or not validTime(deadline) then
		return Result.failure("InvalidRequest")
	end
	local copiedChoices = copyChoices(choices)
	if not copiedChoices then
		return Result.failure("InvalidRequest")
	end
	if state.Deadline ~= nil then
		return Result.failure("WrongState")
	end
	if roundId <= state.RoundId then
		return Result.failure("StaleRound")
	end
	local counts: { [string]: number } = {}
	for _, mapId in copiedChoices do
		counts[mapId] = 0
	end
	state.RoundId = roundId
	state.Choices = copiedChoices
	state.Counts = counts
	state.Votes = {}
	state.Deadline = deadline
	state.Revision += 1
	return Result.success(true)
end

--[=[ Server pad occupancy supplies this command. Leaving a pad never removes its vote. ]=]
local function cast(
	state: State,
	userId: number,
	roundId: number,
	mapId: string,
	now: number
): Result.Result<boolean>
	if
		not Validation.playerId(userId, Limits.MaxInteger)
		or not validIdentity(roundId)
		or not Validation.id(mapId)
		or not validTime(now)
	then
		return Result.failure("InvalidRequest")
	end
	local deadline = state.Deadline
	if deadline == nil then
		return Result.failure("WrongState")
	end
	if roundId ~= state.RoundId then
		return Result.failure("StaleRound")
	end
	if now >= deadline then
		return Result.failure("WrongState")
	end
	if state.Counts[mapId] == nil then
		return Result.failure("UnknownId")
	end
	local previous = state.Votes[userId]
	if previous == mapId then
		return Result.success(false)
	end
	if previous then
		state.Counts[previous] -= 1
	end
	state.Votes[userId] = mapId
	state.Counts[mapId] += 1
	state.Revision += 1
	return Result.success(true)
end

--[=[ Only player removal clears a sticky vote; returns whether a vote changed. ]=]
local function removePlayer(state: State, userId: number): Result.Result<boolean>
	if not Validation.playerId(userId, Limits.MaxInteger) then
		return Result.failure("InvalidRequest")
	end
	if state.Deadline == nil then
		return Result.failure("WrongState")
	end
	local previous = state.Votes[userId]
	if not previous then
		return Result.success(false)
	end
	state.Votes[userId] = nil
	state.Counts[previous] -= 1
	state.Revision += 1
	return Result.success(true)
end

--[=[ Resolve at/after the deadline, uniformly sampling tied leaders, including all-zero votes. ]=]
local function resolve(state: State, roundId: number, now: number): Result.Result<string>
	if not validIdentity(roundId) or not validTime(now) then
		return Result.failure("InvalidRequest")
	end
	local deadline = state.Deadline
	if deadline == nil then
		return Result.failure("WrongState")
	end
	if roundId ~= state.RoundId then
		return Result.failure("StaleRound")
	end
	if now < deadline then
		return Result.failure("WrongState")
	end
	local ties: { string } = {}
	local highest = -1
	for _, mapId in state.Choices do
		local count = state.Counts[mapId]
		if count > highest then
			highest = count
			ties = { mapId }
		elseif count == highest then
			table.insert(ties, mapId)
		end
	end
	local revision = state.Revision
	local ok, index = pcall(state.Random, 1, #ties)
	if not ok or not Validation.integer(index, 1, #ties) or state.Revision ~= revision then
		return Result.failure("Unavailable")
	end
	local winner = ties[index]
	state.Deadline = nil
	state.Revision += 1
	return Result.success(winner)
end

--[=[ Creates an isolated ledger. RNG must return a uniform integer in the inclusive bounds. ]=]
function VoteLedger.new(random: (number, number) -> number): Ledger
	assert(type(random) == "function", "VoteLedger requires an injected RNG")
	local state: State = {
		RoundId = 0,
		Choices = {},
		Counts = {},
		Votes = {},
		Deadline = nil,
		Revision = 0,
		Random = random,
	}
	local ledger: Ledger = {
		open = function(_self: Ledger, roundId: number, choices: { string }, deadline: number)
			return open(state, roundId, choices, deadline)
		end,
		cast = function(_self: Ledger, userId: number, roundId: number, mapId: string, now: number)
			return cast(state, userId, roundId, mapId, now)
		end,
		removePlayer = function(_self: Ledger, userId: number)
			return removePlayer(state, userId)
		end,
		resolve = function(_self: Ledger, roundId: number, now: number)
			return resolve(state, roundId, now)
		end,
		close = function(_self: Ledger)
			if state.Deadline ~= nil then
				state.Deadline = nil
				state.Revision += 1
			end
		end,
		snapshot = function(_self: Ledger): Snapshot
			return table.freeze({
				RoundId = state.RoundId,
				Choices = table.freeze(table.clone(state.Choices)),
				Counts = table.freeze(table.clone(state.Counts)),
				Deadline = state.Deadline,
			})
		end,
	}
	return table.freeze(ledger)
end

return table.freeze(VoteLedger)
