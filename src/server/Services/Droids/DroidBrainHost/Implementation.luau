--!strict
local Service = require("@game/ReplicatedStorage/Shared/Contracts/Service")
local DroidAI = require("@game/ReplicatedStorage/Shared/Contracts/DroidAI")
local Payloads = require("@game/ReplicatedStorage/Shared/Contracts/Payloads")
local Result = require("@game/ReplicatedStorage/Shared/Contracts/Result")
local DeepFreeze = require("@game/ReplicatedStorage/Shared/Util/DeepFreeze")
local Pool = require("@game/ServerScriptService/Server/AI/Actors/Pool")
local Scheduler = require("@game/ServerScriptService/Server/AI/Scheduler")
local Planner = require("@game/ServerScriptService/Server/AI/Scheduler/BatchPlanner")
local Publisher = require("@game/ServerScriptService/Server/AI/SnapshotPublisher")
local Types = require("./Types")
local Implementation = {}
type Job = Planner.Job

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

--[=[ Serial owner of a bounded parallel worker pool. The caller owns the only Heartbeat. ]=]
function Implementation.new(deps: Types.Dependencies): Types.Api
	local config = table.clone(deps.Config)
	config.Policy = table.clone(deps.Config.Policy)
	DeepFreeze.freeze((config :: unknown) :: DeepFreeze.DataTable)
	assert(
		config.WorkerCount >= 1 and config.WorkerCount % 1 == 0 and config.WorkerCount <= 64,
		"Invalid worker count"
	)
	assert(
		config.MaxBatchSize >= 1
			and config.MaxBatchSize <= 128
			and config.MaxBatchSize % 1 == 0
			and config.MaxPendingBatches >= 1
			and config.MaxPendingBatches % 1 == 0,
		"Invalid batch bounds"
	)
	assert(
		config.WorkerTimeoutSeconds > 0
			and config.MaxWorkerRetries >= 0
			and config.MaxWorkerRetries % 1 == 0
			and config.FrameBudgetMs > 0
			and config.MaxDecisionsPerFrame >= 1
			and config.MaxDecisionsPerFrame % 1 == 0,
		"Invalid watchdog"
	)
	local scheduler = Scheduler.new(config)
	local pool: Pool.Api? = nil
	local pending: { [number]: Job } = {}
	local completed: { Payloads.BrainDecision } = {}
	local samples: { number } = {}
	local totalMs, sampleCount = 0, 0
	local frame: DroidAI.Frame? = nil
	local published: SharedTable? = nil
	local initialized, started, destroyed = false, false, false
	local nextJob, dispatched, parallelBatches, failures, timeouts, dropped = 0, 0, 0, 0, 0, 0

	local function onResult(
		worker: Pool.Worker,
		jobId: unknown,
		packet: unknown,
		elapsed: unknown,
		failed: unknown,
		crashed: unknown
	)
		local job = pending[worker.Id]
		if not job or job.Id ~= jobId then
			dropped += 1
			return
		end
		pending[worker.Id] = nil
		parallelBatches += 1
		if type(elapsed) == "number" and finite(elapsed) and elapsed >= 0 then
			totalMs += elapsed
			sampleCount += 1
			table.insert(samples, elapsed)
			if #samples > 128 then
				table.remove(samples, 1)
			end
		end
		if type(failed) == "number" and failed > 0 then
			failures += math.min(failed, config.MaxBatchSize)
		end
		local receivedAt = deps.clock()
		if not finite(receivedAt) or receivedAt < job.Began then
			failures += 1
			dropped += 1
			return
		end
		if receivedAt - job.Began >= config.WorkerTimeoutSeconds then
			timeouts += 1
			failures += 1
			dropped += 1
			return
		end
		if crashed == true then
			local activePool = pool
			if activePool then
				if worker.Retries < config.MaxWorkerRetries then
					activePool.spawn(worker.Id, deps.clock(), worker.Retries + 1)
				else
					activePool.remove(worker.Id)
				end
			end
			return
		end
		local current = frame
		if not current or current.RoundId ~= job.RoundId or typeof(packet) ~= "SharedTable" then
			dropped += 1
			return
		end
		local ok, data = pcall(Publisher.decode, packet :: SharedTable)
		if not ok then
			failures += 1
			return
		end
		local decisions = (data :: unknown) :: { Payloads.BrainDecision }
		local generation: { [string]: number } = {}
		for _, agent in current.Agents do
			generation[agent.Entity.Id] = agent.Entity.Generation
		end
		local seen: { [string]: boolean } = {}
		for index, decision in decisions do
			if
				index > config.MaxBatchSize
				or #completed >= config.MaxDecisionsPerFrame * config.MaxPendingBatches
			then
				dropped += 1
				break
			end
			local entity = decision.Entity
			if
				entity.RoundId == job.RoundId
				and decision.SnapshotSequence == job.Sequence
				and job.Agents[entity.Id] == entity.Generation
				and generation[entity.Id] == entity.Generation
				and not seen[entity.Id]
			then
				seen[entity.Id] = true
				table.insert(completed, decision)
			else
				dropped += 1
			end
		end
	end
	local function ensurePool()
		if not pool then
			local fresh = Pool.new(deps.workerTemplate, deps.parent, onResult)
			pool = fresh
			for id = 1, config.WorkerCount do
				fresh.spawn(id, deps.clock(), 0)
			end
		end
	end
	local function clear()
		if pool then
			pool.destroy()
			pool = nil
		end
		table.clear(pending)
		table.clear(completed)
		scheduler.clear()
		frame = nil
		published = nil
	end
	local function watchdog(now: number)
		if not pool then
			return
		end
		for id, worker in pool.Workers do
			local job = pending[id]
			local began = if job then job.Began else worker.CreatedAt
			if (job or not worker.Ready) and now - began >= config.WorkerTimeoutSeconds then
				timeouts += 1
				failures += 1
				pending[id] = nil
				local retries = worker.Retries + 1
				if retries <= config.MaxWorkerRetries then
					pool.spawn(id, now, retries)
				else
					pool.remove(id)
				end
			end
		end
	end
	local function configure(nextFrame: DroidAI.Frame): Result.Result<boolean>
		if not started then
			return Result.failure("NotReady")
		end
		local current = frame
		if
			current
			and (
				current.RoundId ~= nextFrame.RoundId
				or nextFrame.Sequence <= current.Sequence
				or nextFrame.Now < current.Now
			)
		then
			return Result.failure("StaleRound")
		end
		local result = Publisher.publish(nextFrame, config)
		if not result.Ok then
			return result
		end
		published = result.Value
		frame = (Publisher.decode(result.Value) :: unknown) :: DroidAI.Frame
		ensurePool()
		return Result.success(true)
	end
	local self: Types.Api = {
		Name = "DroidBrainHost",
		IsStub = false,
		Init = function(_self: Service.Interface)
			if not destroyed then
				initialized = true
			end
		end,
		Start = function(_self: Service.Interface)
			if initialized and not destroyed then
				started = true
				ensurePool()
			end
		end,
		Stop = function(_self: Service.Interface)
			started = false
			clear()
		end,
		Destroy = function(_self: Service.Interface)
			started = false
			destroyed = true
			clear()
		end,
		IsStarted = function(_self: Service.Interface): boolean
			return started
		end,
		Call = function(
			_self: Service.Interface,
			_command: string,
			_arguments: Service.Arguments?
		): Service.StubResult
			local result: Service.StubResult = { Ok = false, Code = "NotReady" }
			return table.freeze(result)
		end,
		configureFrame = configure,
		PublishSnapshot = function(
			_self: Service.Interface,
			roundId: number,
			snapshots: { Payloads.TargetSnapshot }
		): Result.Result<boolean>
			local current = frame
			if not current or current.RoundId ~= roundId then
				return Result.failure("NotReady")
			end
			local nextFrame = table.clone(current)
			nextFrame.Targets = (snapshots :: unknown) :: { DroidAI.Target }
			nextFrame.Sequence += 1
			nextFrame.Now = deps.clock()
			return configure(nextFrame)
		end,
		Schedule = function(
			_self: Service.Interface,
			roundId: number,
			budgetMs: number
		): Result.Result<boolean>
			if not started then
				return Result.failure("NotReady")
			end
			if not finite(budgetMs) or budgetMs <= 0 then
				return Result.failure("InvalidRequest")
			end
			local current, snapshot = frame, published
			if not current or not snapshot or current.RoundId ~= roundId then
				return Result.failure("StaleRound")
			end
			local now = deps.clock()
			if not finite(now) then
				return Result.failure("Unavailable")
			end
			watchdog(now)
			local activePool = pool
			if not activePool then
				return Result.failure("NotReady")
			end
			local batches = Planner.choose(current, config, activePool, pending, scheduler, now, budgetMs)
			if next(batches) == nil then
				return Result.success(false)
			end
			local generation: { [string]: number } = {}
			for _, agent in current.Agents do
				generation[agent.Entity.Id] = agent.Entity.Generation
			end
			for workerId, batch in batches do
				nextJob += 1
				local agents: { [string]: number } = {}
				for _, id in batch do
					agents[id] = generation[id]
				end
				pending[workerId] = {
					Id = nextJob,
					RoundId = roundId,
					Sequence = current.Sequence,
					Began = now,
					Agents = agents,
				}
				local worker = activePool.Workers[workerId]
				local ok = pcall(function()
					worker.Actor:SendMessage(
						"Decide",
						nextJob,
						snapshot,
						SharedTable.cloneAndFreeze(SharedTable.new(batch), true)
					)
				end)
				if ok then
					dispatched += #batch
				else
					pending[workerId] = nil
					failures += 1
				end
			end
			return Result.success(true)
		end,
		CollectDecisions = function(
			_self: Service.Interface,
			roundId: number
		): Result.Result<{ Payloads.BrainDecision }>
			local current = frame
			if not started or not current or current.RoundId ~= roundId then
				return Result.failure("StaleRound")
			end
			local generation: { [string]: number } = {}
			for _, agent in current.Agents do
				if agent.Hp > 0 then
					generation[agent.Entity.Id] = agent.Entity.Generation
				end
			end
			local result: { Payloads.BrainDecision } = {}
			for _, decision in completed do
				if
					decision.Entity.RoundId == roundId
					and generation[decision.Entity.Id] == decision.Entity.Generation
					and decision.SnapshotSequence <= current.Sequence
				then
					table.insert(result, decision)
				else
					dropped += 1
				end
			end
			completed = {}
			return Result.success(table.freeze(result))
		end,
		StopRound = function(_self: Service.Interface, roundId: number): Result.Result<boolean>
			if frame and frame.RoundId ~= roundId then
				return Result.failure("StaleRound")
			end
			clear()
			return Result.success(true)
		end,
		metrics = function(): DroidAI.Metrics
			local sorted = table.clone(samples)
			table.sort(sorted)
			local workers, outstanding = 0, 0
			if pool then
				for _ in pool.Workers do
					workers += 1
				end
			end
			for _ in pending do
				outstanding += 1
			end
			return table.freeze({
				Workers = workers,
				Pending = outstanding,
				Dispatched = dispatched,
				ParallelBatches = parallelBatches,
				Failures = failures,
				Timeouts = timeouts,
				Dropped = dropped,
				AverageMs = if sampleCount > 0 then totalMs / sampleCount else 0,
				P95Ms = sorted[math.max(1, math.ceil(#sorted * 0.95))] or 0,
			})
		end,
	}
	return self
end
return table.freeze(Implementation)
