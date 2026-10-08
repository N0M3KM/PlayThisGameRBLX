--!strict
-- Prepared only; no unit suite was rerun for this implementation.
local Template = require("../../../src/server/Services/Data/ProfileTemplate")
local Types = require("../../../src/server/Services/Data/ProfileTypes")
local Operations = require("../../../src/server/Services/Data/ProfileOperations")
local Transaction = require("../../../src/server/Services/Data/DataService/Transaction")
local Result = require("../../../src/shared/Contracts/Result")

local function command(): Operations.Command
	return {
		TransactionId = "purchase:1",
		UserId = 1,
		ExpectedRevision = 0,
		Reason = "Shop",
		Fingerprint = "gear|test|10",
	}
end

do
	local profile = Template.new()
	profile.Coins = 20
	local calls = 0
	local function buy(candidate: Types.Profile): Result.Result<boolean>
		calls += 1
		candidate.Coins -= 10
		table.insert(candidate.Inventory.Gears, "test")
		return Result.success(true)
	end
	local intent = command()
	local first = Transaction.applyMutation(profile, intent, buy)
	assert(first.Ok and not first.Value.AlreadyApplied, "First purchase must grant once")
	assert(
		profile.Coins == 10 and #profile.Inventory.Gears == 1,
		"Coin deduction and item share one candidate"
	)
	intent.ExpectedRevision = profile.Revision
	local retry = Transaction.applyMutation(profile, intent, buy, function()
		return false
	end)
	assert(retry.Ok and retry.Value.AlreadyApplied and calls == 1, "Retry precedes revision and lobby guard")
	intent.Fingerprint = "gear|other|10"
	local changed = Transaction.applyMutation(profile, intent, buy)
	assert(not changed.Ok and changed.Code == "InvalidRequest", "An operation ID cannot change intent")
end

do
	local profile = Template.new()
	local intent = command()
	intent.ExpectedRevision = 1
	local stale = Transaction.applyMutation(profile, intent, function(_candidate)
		error("Must not execute")
	end)
	assert(not stale.Ok and stale.Code == "WrongState", "Stale revisions cannot run a mutator")
	intent.ExpectedRevision = 0
	local yielded = Transaction.applyMutation(profile, intent, function(_candidate)
		coroutine.yield()
		return Result.success(true)
	end)
	assert(not yielded.Ok and yielded.Code == "InvalidRequest", "Yielding mutation must be cancelled")
	assert(
		profile.Revision == 0 and next(profile.ProcessedTransactions) == nil,
		"A rejected callback leaves no journal entry"
	)
	assert(not Transaction.guard(function()
		coroutine.yield()
		return true
	end), "Yielding guard must be cancelled")
end

return true
