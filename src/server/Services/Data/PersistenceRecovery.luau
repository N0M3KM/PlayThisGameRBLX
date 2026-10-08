--!strict
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local PersistenceRecovery = {}
export type Runtime = { clock: () -> number, wait: (number) -> () }
export type Policy = { MaxAttempts: number, BaseDelaySeconds: number, MaxDelaySeconds: number }
export type Counters = { Attempts: number, Failures: number, Retries: number, LastCode: Result.ErrorCode? }

function PersistenceRecovery.counters(): Counters
	return { Attempts = 0, Failures = 0, Retries = 0, LastCode = nil }
end

function PersistenceRecovery.snapshot(counters: Counters): Counters
	return table.freeze(table.clone(counters))
end

--[=[ Retry only an operation with no published candidate or uncertain write.
	Load callers retain ownership of successful sessions and enforce their deadline
	inside the adapter. Save/commit operations must never use this helper.
]=]
function PersistenceRecovery.run<T>(
	runtime: Runtime,
	policy: Policy,
	deadline: number,
	cancelled: () -> boolean,
	operation: () -> Result.Result<T>,
	retryable: (Result.ErrorCode) -> boolean,
	counters: Counters?
): Result.Result<T>
	assert(
		policy.MaxAttempts >= 1 and policy.MaxAttempts % 1 == 0 and policy.MaxAttempts < math.huge,
		"Invalid retry count"
	)
	assert(
		policy.BaseDelaySeconds > 0
			and policy.BaseDelaySeconds <= policy.MaxDelaySeconds
			and policy.MaxDelaySeconds < math.huge,
		"Invalid retry delays"
	)
	local stats = counters or PersistenceRecovery.counters()
	local lastCode: Result.ErrorCode = "Unavailable"
	for attempt = 1, policy.MaxAttempts do
		if cancelled() then
			return Result.failure("NotReady")
		end
		if runtime.clock() >= deadline then
			return Result.failure(lastCode)
		end
		stats.Attempts += 1
		local ok, outcome = pcall(operation)
		if ok and outcome.Ok then
			return outcome
		end
		local code: Result.ErrorCode = "Unavailable"
		if ok and not outcome.Ok then
			code = outcome.Code
		end
		stats.Failures += 1
		stats.LastCode = code
		lastCode = code
		if attempt == policy.MaxAttempts or not retryable(code) then
			return Result.failure(code)
		end
		if cancelled() then
			return Result.failure("NotReady")
		end
		local remaining = deadline - runtime.clock()
		if remaining <= 0 then
			return Result.failure(code)
		end
		stats.Retries += 1
		runtime.wait(math.min(policy.BaseDelaySeconds * 2 ^ (attempt - 1), policy.MaxDelaySeconds, remaining))
	end
	return Result.failure(lastCode)
end

return table.freeze(PersistenceRecovery)
