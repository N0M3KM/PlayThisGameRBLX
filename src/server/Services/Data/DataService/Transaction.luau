--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config/Data")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local ProfileTypes = require("../ProfileTypes")
local Operations = require("../ProfileOperations")
local Transaction = {}
local readMetatable = (getmetatable :: unknown) :: (unknown) -> unknown
local REASONS: { [string]: boolean } = table.freeze({
	Kill = true,
	Boss = true,
	Survival = true,
	Shop = true,
	Receipt = true,
	Wheel = true,
	Quest = true,
	Utility = true,
	Inventory = true,
	Boost = true,
})
local KEYS: { [string]: boolean } = table.freeze({
	TransactionId = true,
	UserId = true,
	ExpectedRevision = true,
	Reason = true,
	CoinDelta = true,
	XpDelta = true,
})

local function integer(value: unknown, minimum: number): boolean
	return type(value) == "number"
		and value == value
		and value >= minimum
		and value <= Config.MaxInteger
		and value % 1 == 0
end

local function finite(value: unknown, minimum: number): boolean
	return type(value) == "number" and value == value and value >= minimum and value <= Config.MaxInteger
end

--[=[ Validates the canonical server-only coin/XP command before profile lookup or allocation. ]=]
function Transaction.validate(value: unknown): boolean
	if type(value) ~= "table" or readMetatable(value) ~= nil then
		return false
	end
	local data = value :: { [string]: any }
	for key in data do
		if not KEYS[key] then
			return false
		end
	end
	return type(data.TransactionId) == "string"
		and #data.TransactionId > 0
		and #data.TransactionId <= Config.MaxTransactionIdLength
		and integer(data.UserId, -Config.MaxInteger)
		and data.UserId ~= 0
		and integer(data.ExpectedRevision, 0)
		and type(data.Reason) == "string"
		and REASONS[data.Reason] == true
		and finite(data.CoinDelta, -Config.MaxInteger)
		and finite(data.XpDelta, -Config.MaxInteger)
end

function Transaction.fingerprint(transaction: Payloads.EconomyTransaction): string
	return string.format(
		"%.0f|%.0f|%s|%.17g|%.17g",
		transaction.UserId,
		transaction.ExpectedRevision,
		transaction.Reason,
		transaction.CoinDelta,
		transaction.XpDelta
	)
end

function Transaction.validateMutation(command: Operations.Command): boolean
	return Transaction.validate({
		TransactionId = command.TransactionId,
		UserId = command.UserId,
		ExpectedRevision = command.ExpectedRevision,
		Reason = command.Reason,
		CoinDelta = 0,
		XpDelta = 0,
	}) and type(command.Fingerprint) == "string" and #command.Fingerprint > 0 and #command.Fingerprint <= Config.MaxStringLength - Config.MaxTransactionIdLength
end

--[=[ Rejects yielding callbacks before they can escape the profile critical section. ]=]
function Transaction.guard(guard: Operations.Guard?): boolean
	if not guard then
		return true
	end
	local thread = coroutine.create(guard)
	local ok, value = coroutine.resume(thread)
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		return false
	end
	return ok and value == true
end

function Transaction.applyMutation(
	candidate: ProfileTypes.Profile,
	command: Operations.Command,
	mutator: Operations.Mutator,
	guard: Operations.Guard?
): Result.Result<Payloads.TransactionReceipt>
	-- ExpectedRevision is a concurrency precondition, not part of the durable operation identity.
	local fingerprint =
		string.format("mutation|%.0f|%s|%s", command.UserId, command.Reason, command.Fingerprint)
	local existing = candidate.ProcessedTransactions[command.TransactionId]
	if existing then
		if existing.Fingerprint ~= fingerprint then
			return Result.failure("InvalidRequest")
		end
		return Result.success(table.freeze({
			TransactionId = command.TransactionId,
			Revision = existing.Revision,
			AlreadyApplied = true,
		}))
	end
	if candidate.Revision ~= command.ExpectedRevision or not Transaction.guard(guard) then
		return Result.failure("WrongState")
	end
	local count = 0
	for _ in candidate.ProcessedTransactions do
		count += 1
	end
	if count >= Config.MaxTransactions or candidate.Revision >= Config.MaxInteger then
		return Result.failure("LimitReached")
	end
	local revision = candidate.Revision
	local thread = coroutine.create(mutator)
	local ok, outcome = coroutine.resume(thread, candidate)
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		return Result.failure("InvalidRequest")
	end
	if not ok then
		return Result.failure("Unavailable")
	end
	if not outcome.Ok then
		return Result.failure(outcome.Code)
	end
	if not outcome.Value or candidate.Revision ~= revision then
		return Result.failure("WrongState")
	end
	candidate.Revision += 1
	candidate.ProcessedTransactions[command.TransactionId] =
		{ Revision = candidate.Revision, Fingerprint = fingerprint }
	return Result.success(table.freeze({
		TransactionId = command.TransactionId,
		Revision = candidate.Revision,
		AlreadyApplied = false,
	}))
end

--[=[ Mutates only a detached candidate. Journal capacity fails closed without unsafe pruning. ]=]
function Transaction.apply(
	candidate: ProfileTypes.Profile,
	transaction: Payloads.EconomyTransaction
): Result.Result<Payloads.TransactionReceipt>
	local fingerprint = Transaction.fingerprint(transaction)
	local existing = candidate.ProcessedTransactions[transaction.TransactionId]
	if existing then
		if existing.Fingerprint ~= fingerprint then
			return Result.failure("InvalidRequest")
		end
		return Result.success(table.freeze({
			TransactionId = transaction.TransactionId,
			Revision = existing.Revision,
			AlreadyApplied = true,
		}))
	end
	if candidate.Revision ~= transaction.ExpectedRevision then
		return Result.failure("WrongState")
	end
	local count = 0
	for _ in candidate.ProcessedTransactions do
		count += 1
	end
	if count >= Config.MaxTransactions or candidate.Revision >= Config.MaxInteger then
		return Result.failure("LimitReached")
	end
	local coins, xp = candidate.Coins + transaction.CoinDelta, candidate.TotalXP + transaction.XpDelta
	if coins < 0 then
		return Result.failure("InsufficientFunds")
	end
	if not finite(coins, 0) or not finite(xp, 0) then
		return Result.failure("InvalidRequest")
	end
	candidate.Coins, candidate.TotalXP = coins, xp
	candidate.Revision += 1
	candidate.ProcessedTransactions[transaction.TransactionId] =
		{ Revision = candidate.Revision, Fingerprint = fingerprint }
	return Result.success(table.freeze({
		TransactionId = transaction.TransactionId,
		Revision = candidate.Revision,
		AlreadyApplied = false,
	}))
end

return table.freeze(Transaction)
