--!strict
-- Prepared pure load-retry/scheduling cases. No real persistence or suite rerun.
local Result = require("../../../src/shared/Contracts/Result")
local Recovery = require("../../../src/server/Services/Data/PersistenceRecovery")
local SaveScheduler = require("../../../src/server/Services/Data/SaveScheduler")
local policy: Recovery.Policy = { MaxAttempts = 3, BaseDelaySeconds = 0.5, MaxDelaySeconds = 2 }
local function retryable(code: Result.ErrorCode): boolean
	return code == "Unavailable" or code == "RateLimited"
end

do
	local now, calls = 0, 0
	local counters = Recovery.counters()
	local runtime: Recovery.Runtime = {
		clock = function()
			return now
		end,
		wait = function(delay)
			now += delay
		end,
	}
	local outcome = Recovery.run(runtime, policy, 10, function()
		return false
	end, function(): Result.Result<number>
		calls += 1
		return if calls == 3 then Result.success(42) else Result.failure("Unavailable")
	end, retryable, counters)
	assert(outcome.Ok and outcome.Value == 42, "Transient load eventually succeeds")
	assert(calls == 3 and now == 1.5, "Backoff stays bounded")
	local snapshot = Recovery.snapshot(counters)
	assert(
		snapshot.Attempts == 3 and snapshot.Failures == 2 and table.isfrozen(snapshot),
		"Aggregate counters are immutable"
	)
end

do
	local now, calls = 0, 0
	local cancelled = false
	local runtime: Recovery.Runtime = {
		clock = function()
			return now
		end,
		wait = function(delay)
			now += delay
			cancelled = true
		end,
	}
	local outcome = Recovery.run(runtime, policy, 10, function()
		return cancelled
	end, function(): Result.Result<boolean>
		calls += 1
		return Result.failure("Unavailable")
	end, retryable)
	assert(
		not outcome.Ok and outcome.Code == "NotReady" and calls == 1,
		"Generation cancellation prevents another load"
	)
end

do
	local now, calls = 0, 0
	local runtime: Recovery.Runtime = {
		clock = function()
			return now
		end,
		wait = function(delay)
			now += delay
		end,
	}
	local outcome = Recovery.run(runtime, policy, 0.25, function()
		return false
	end, function(): Result.Result<boolean>
		calls += 1
		return Result.failure("RateLimited")
	end, retryable)
	assert(
		not outcome.Ok and outcome.Code == "RateLimited" and calls == 1 and now == 0.25,
		"Global deadline bounds retries and preserves error"
	)
	calls = 0
	local invalid = Recovery.run(runtime, policy, 10, function()
		return false
	end, function(): Result.Result<boolean>
		calls += 1
		return Result.failure("InvalidRequest")
	end, retryable)
	assert(
		not invalid.Ok and invalid.Code == "InvalidRequest" and calls == 1,
		"Invalid profile never retries or substitutes defaults"
	)
end

do
	local now = 0
	local timer: thread? = nil
	local timerCancelled = false
	local callbacks: { () -> () } = {}
	local saved: { number } = {}
	local scheduler = SaveScheduler.new({
		clock = function()
			return now
		end,
		wait = function(_delay)
			coroutine.yield()
		end,
		startTimer = function(callback)
			local worker = coroutine.create(callback)
			timer = worker
			assert(coroutine.resume(worker), "Scheduler timer starts")
			return function()
				timerCancelled = true
			end
		end,
		spawnSave = function(callback)
			table.insert(callbacks, callback)
		end,
	}, { IntervalSeconds = 10, TickSeconds = 1, MaxConcurrent = 2, MaxPerTick = 1 }, {
		list = function()
			return { 1, 2, 3 }
		end,
		save = function(userId)
			table.insert(saved, userId)
			return Result.success(true)
		end,
	})
	local function advance(time: number)
		now = time
		assert(timer, "Timer must exist")
		assert(coroutine.resume(timer :: thread), "Scheduler tick succeeds")
	end
	scheduler.start()
	advance(10)
	assert(#callbacks == 1, "Per-tick dispatch is bounded")
	advance(11)
	advance(12)
	assert(#callbacks == 2 and scheduler.metrics().InFlight == 2, "Global concurrent saves are bounded")
	callbacks[1]()
	advance(13)
	assert(#callbacks == 3, "Other due players progress after a save finishes")
	callbacks[2]()
	callbacks[3]()
	assert(saved[1] == 1 and saved[2] == 2 and saved[3] == 3, "Each user has only one pending save")
	scheduler.stop()
	assert(
		timerCancelled and scheduler.drain(now) and table.isfrozen(scheduler.metrics()),
		"Stop cancels timer and finished writes drain"
	)
end

return true
