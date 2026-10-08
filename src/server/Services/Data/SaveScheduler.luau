--!strict
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local SaveScheduler = {}
export type Runtime = {
	clock: () -> number,
	wait: (number) -> (),
	startTimer: (() -> ()) -> () -> (),
	spawnSave: (() -> ()) -> (),
}
export type Policy =
	{ IntervalSeconds: number, TickSeconds: number, MaxConcurrent: number, MaxPerTick: number }
export type Metrics = {
	Attempts: number,
	Failures: number,
	Completed: number,
	BudgetDenied: number,
	InFlight: number,
	LastCode: Result.ErrorCode?,
}
export type Options = {
	list: () -> { number },
	save: (number) -> Result.Result<boolean>,
	budgetAllowed: (() -> boolean)?,
	changed: ((Metrics) -> ())?,
}
export type Scheduler =
	{ start: () -> (), stop: () -> (), drain: (number) -> boolean, metrics: () -> Metrics }

--[=[ One owned timer schedules bounded saves. In-flight writes finish under their
	existing session owner; stopping never cancels an uncertain persistence coroutine.
	The optional budget gate is injected policy, not proof of real DataStore budgets.
]=]
function SaveScheduler.new(runtime: Runtime, policy: Policy, options: Options): Scheduler
	assert(
		policy.IntervalSeconds > 0
			and policy.IntervalSeconds < math.huge
			and policy.TickSeconds > 0
			and policy.TickSeconds < math.huge,
		"Invalid autosave intervals"
	)
	assert(
		policy.MaxConcurrent >= 1
			and policy.MaxConcurrent % 1 == 0
			and policy.MaxPerTick >= 1
			and policy.MaxPerTick % 1 == 0,
		"Invalid autosave limits"
	)
	local stopped = true
	local started = false
	local cancelTimer = function() end
	local due: { [number]: number } = {}
	local inFlight: { [number]: boolean } = {}
	local stats: Metrics =
		{ Attempts = 0, Failures = 0, Completed = 0, BudgetDenied = 0, InFlight = 0, LastCode = nil }
	local function publish()
		if options.changed then
			pcall(options.changed, table.freeze(table.clone(stats)))
		end
	end
	local function tick()
		local now = runtime.clock()
		local present: { [number]: boolean } = {}
		local candidates: { number } = {}
		for _, userId in options.list() do
			present[userId] = true
			due[userId] = due[userId] or now + policy.IntervalSeconds
			if not inFlight[userId] and (due[userId] :: number) <= now then
				table.insert(candidates, userId)
			end
		end
		for userId in due do
			if not present[userId] then
				due[userId] = nil
			end
		end
		table.sort(candidates, function(left, right)
			local leftDue, rightDue = due[left] :: number, due[right] :: number
			return if leftDue == rightDue then left < right else leftDue < rightDue
		end)
		local dispatched = 0
		for _, userId in candidates do
			if stopped or stats.InFlight >= policy.MaxConcurrent or dispatched >= policy.MaxPerTick then
				break
			end
			if options.budgetAllowed then
				local allowedOk, allowed = pcall(options.budgetAllowed)
				if not allowedOk or not allowed then
					stats.BudgetDenied += 1
					publish()
					break
				end
			end
			dispatched += 1
			inFlight[userId] = true
			stats.InFlight += 1
			stats.Attempts += 1
			runtime.spawnSave(function()
				local ok, outcome = pcall(options.save, userId)
				stats.InFlight -= 1
				inFlight[userId] = nil
				if ok and outcome.Ok then
					stats.Completed += 1
					due[userId] = runtime.clock() + policy.IntervalSeconds
				else
					local code: Result.ErrorCode = "Unavailable"
					if ok and not outcome.Ok then
						code = outcome.Code
					end
					stats.Failures += 1
					stats.LastCode = code
					-- Busy records may try later. Uncertain saves are fenced/removed by the boundary.
					due[userId] = runtime.clock()
						+ (if code == "NotReady" then policy.TickSeconds else policy.IntervalSeconds)
				end
				publish()
			end)
		end
	end
	return table.freeze({
		start = function()
			assert(not started, "Autosave scheduler cannot restart")
			started, stopped = true, false
			cancelTimer = runtime.startTimer(function()
				while not stopped do
					tick()
					runtime.wait(policy.TickSeconds)
				end
			end)
		end,
		stop = function()
			stopped = true
			cancelTimer()
		end,
		drain = function(deadline: number): boolean
			while stats.InFlight > 0 and runtime.clock() < deadline do
				runtime.wait(math.min(policy.TickSeconds, math.max(0, deadline - runtime.clock())))
			end
			return stats.InFlight == 0
		end,
		metrics = function(): Metrics
			return table.freeze(table.clone(stats))
		end,
	})
end

return table.freeze(SaveScheduler)
