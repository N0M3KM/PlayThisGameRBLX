--!strict
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Data)
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Service = require(Shared.Contracts.Service)
local Scope = require(Shared.Util.Scope)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local ProfileAdapter = require(script.Parent.Parent.ProfileAdapter)
local ProfileTypes = require(script.Parent.Parent.ProfileTypes)
local ProfileOperations = require(script.Parent.Parent.ProfileOperations)
local PersistenceRecovery = require(script.Parent.Parent.PersistenceRecovery)
local SaveScheduler = require(script.Parent.Parent.SaveScheduler)
local DataSnapshot = require(script.Parent.DataSnapshot)
local SessionRecord = require(script.Parent.SessionRecord)
local Transaction = require(script.Parent.Transaction)
local ShutdownRegistry = require(script.Parent.ShutdownRegistry)
local Implementation = {}
export type Metrics = { Loads: PersistenceRecovery.Counters, Saves: SaveScheduler.Metrics? }
export type Options = { budgetAllowed: (() -> boolean)?, metrics: ((Metrics) -> ())? }

--[=[ Injectable real data boundary. No package/store is opened by requiring this module.
	Stop drains and closes the adapter permanently; construct a fresh service to restart.
]=]
function Implementation.new(
	adapter: ProfileAdapter.Adapter,
	changed: ((Payloads.PlayerDataSnapshot) -> ())?,
	options: Options?
): ProfileOperations.Boundary
	local scope = Scope.new()
	local records: { [number]: SessionRecord.Record } = {}
	local generations: { [number]: number } = {}
	local loading: { [number]: number } = {}
	local connections: { RBXScriptConnection } = {}
	local scheduler: SaveScheduler.Scheduler? = nil
	local loadCounters = PersistenceRecovery.counters()
	local closed = false
	local unregisterShutdown = function() end
	local jobs = 0
	local service: ProfileOperations.Boundary
	local function publishMetrics()
		if options and options.metrics then
			pcall(
				options.metrics,
				table.freeze({
					Loads = PersistenceRecovery.snapshot(loadCounters),
					Saves = if scheduler then scheduler.metrics() else nil,
				})
			)
		end
	end
	local function spawnOwned(callback: () -> ())
		jobs += 1
		task.spawn(function()
			local ok = pcall(callback)
			jobs -= 1
			if not ok then
				warn("DataService owned operation failed")
			end
		end)
	end
	local function publish(userId: number, record: SessionRecord.Record)
		if
			changed
			and records[userId] == record
			and not record.Fenced
			and Players:GetPlayerByUserId(userId)
		then
			local ok = pcall(changed, DataSnapshot.create(userId, record.Committed))
			if not ok then
				warn("DataService snapshot listener failed")
			end
		end
	end
	local function detach(userId: number, record: SessionRecord.Record)
		if records[userId] == record then
			records[userId] = nil
		end
		record.Fenced = true
		record.DisconnectedAt = record.DisconnectedAt or os.clock()
		spawnOwned(function()
			SessionRecord.release(record, os.clock() + Config.ProfileReleaseTimeoutSeconds)
		end)
	end
	local function current(userId: number): SessionRecord.Record?
		local record = records[userId]
		if
			not service:IsStarted()
			or closed
			or not record
			or record.Fenced
			or not record.Session.isActive()
		then
			return nil
		end
		return record
	end
	local function commit(
		userId: number,
		record: SessionRecord.Record,
		candidate: ProfileTypes.Profile,
		checkpointTime: number,
		guard: ProfileOperations.Guard?
	): Result.Result<boolean>
		local ok, outcome = pcall(
			SessionRecord.commit,
			record,
			candidate,
			checkpointTime,
			os.clock() + Config.CommitTimeoutSeconds,
			function(): boolean
				return current(userId) == record and Transaction.guard(guard)
			end
		)
		record.Busy = false
		if not ok then
			record.Fenced = true
		end
		if record.Fenced then
			detach(userId, record)
		end
		if not ok then
			return Result.failure("Unavailable")
		end
		if outcome.Ok then
			publish(userId, record)
		end
		return outcome
	end
	local function disconnectPlayer(player: Player)
		local userId = player.UserId
		generations[userId] = (generations[userId] or 0) + 1
		local record = records[userId]
		if record then
			detach(userId, record)
		end
	end
	local function stop()
		closed = true
		unregisterShutdown()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		if scheduler then
			scheduler.stop()
		end
		local deadline = os.clock() + Config.ShutdownTimeoutSeconds
		for userId, record in records do
			record.Fenced = true
			record.DisconnectedAt = record.DisconnectedAt or os.clock()
			records[userId] = nil
			spawnOwned(function()
				SessionRecord.release(record, deadline)
			end)
		end
		while jobs > 0 and os.clock() < deadline do
			task.wait(Config.ProfilePollIntervalSeconds)
		end
		local ok, outcome = pcall(adapter.destroy, deadline)
		if not ok or not outcome.Ok then
			warn("DataService shutdown drain did not confirm completion")
		end
	end
	local facade = Lifecycle.new("DataService", scope, {
		Start = function()
			assert(not closed, "DataService adapter is closed; construct a new service")
			unregisterShutdown = ShutdownRegistry.add(service)
			table.insert(
				connections,
				Players.PlayerAdded:Connect(function(player)
					spawnOwned(function()
						service:OpenSession(player.UserId)
					end)
				end)
			)
			table.insert(connections, Players.PlayerRemoving:Connect(disconnectPlayer))
			for _, player in Players:GetPlayers() do
				spawnOwned(function()
					service:OpenSession(player.UserId)
				end)
			end
			local autosave = SaveScheduler.new({
				clock = os.clock,
				wait = task.wait,
				spawnSave = spawnOwned,
				startTimer = function(callback: () -> ()): () -> ()
					local timer = task.spawn(callback)
					return function()
						if coroutine.status(timer) ~= "dead" then
							task.cancel(timer)
						end
					end
				end,
			}, {
				IntervalSeconds = Config.AutosaveSeconds,
				TickSeconds = Config.AutosaveTickSeconds,
				MaxConcurrent = Config.MaxConcurrentAutosaves,
				MaxPerTick = Config.MaxAutosavesPerTick,
			}, {
				list = function(): { number }
					local userIds: { number } = {}
					for userId, record in records do
						if not record.Fenced then
							table.insert(userIds, userId)
						end
					end
					return userIds
				end,
				save = function(userId: number): Result.Result<boolean>
					return service:Save(userId)
				end,
				budgetAllowed = if options then options.budgetAllowed else nil,
				changed = function(_metrics: SaveScheduler.Metrics)
					publishMetrics()
				end,
			})
			scheduler = autosave
			autosave.start()
		end,
		Stop = stop,
	})
	service = (facade :: unknown) :: ProfileOperations.Boundary
	service.OpenSession = function(_self: Service.Interface, userId: number): Result.Result<boolean>
		if not service:IsStarted() or closed or not Players:GetPlayerByUserId(userId) then
			return Result.failure("NotReady")
		end
		if records[userId] or loading[userId] then
			return Result.failure("WrongState")
		end
		local generation = generations[userId] or 0
		loading[userId] = generation
		local function cancelled(): boolean
			return closed
				or not service:IsStarted()
				or (generations[userId] or 0) ~= generation
				or Players:GetPlayerByUserId(userId) == nil
		end
		local deadline = os.clock() + Config.LoadTimeoutSeconds
		local outcome = PersistenceRecovery.run(
			{ clock = os.clock, wait = task.wait },
			{
				MaxAttempts = Config.LoadMaxAttempts,
				BaseDelaySeconds = Config.LoadRetryBaseSeconds,
				MaxDelaySeconds = Config.LoadRetryMaxSeconds,
			},
			deadline,
			cancelled,
			function(): Result.Result<ProfileAdapter.Session>
				return adapter.load(userId, cancelled, deadline)
			end,
			function(code: Result.ErrorCode): boolean
				return code == "Unavailable" or code == "RateLimited"
			end,
			loadCounters
		)
		loading[userId] = nil
		publishMetrics()
		if not outcome.Ok then
			return Result.failure(outcome.Code)
		end
		local session = outcome.Value
		if cancelled() then
			pcall(session.release, os.clock() + Config.ProfileReleaseTimeoutSeconds)
			return Result.failure("NotReady")
		end
		local recordOk, record = pcall(SessionRecord.new, session)
		if not recordOk then
			pcall(session.release, os.clock() + Config.ProfileReleaseTimeoutSeconds)
			return Result.failure("Unavailable")
		end
		records[userId] = record
		record.Disconnect = session.onLost(function()
			detach(userId, record)
		end)
		if records[userId] ~= record or not session.isActive() then
			return Result.failure("Unavailable")
		end
		publish(userId, record)
		return Result.success(true)
	end
	service.Read = function(
		_self: Service.Interface,
		userId: number
	): Result.Result<Payloads.PlayerDataSnapshot>
		local record = current(userId)
		if not record then
			return Result.failure("NotReady")
		end
		return Result.success(DataSnapshot.create(userId, record.Committed))
	end
	service.Transact = function(
		_self: Service.Interface,
		transaction: Payloads.EconomyTransaction
	): Result.Result<Payloads.TransactionReceipt>
		if not Transaction.validate(transaction) then
			return Result.failure("InvalidRequest")
		end
		local userId = transaction.UserId
		local record = current(userId)
		if not record then
			return Result.failure("NotReady")
		end
		if record.Busy then
			return Result.failure("NotReady")
		end
		record.Busy = true
		local candidate, checkpointTime = SessionRecord.candidate(record)
		local receipt = Transaction.apply(candidate, transaction)
		if not receipt.Ok or receipt.Value.AlreadyApplied then
			record.Busy = false
			return receipt
		end
		local outcome = commit(userId, record, candidate, checkpointTime)
		return if outcome.Ok then receipt else Result.failure(outcome.Code)
	end
	service.ReadBoosts = function(
		_self: Service.Interface,
		userId: number
	): Result.Result<ProfileOperations.BoostSnapshot>
		local record = current(userId)
		if not record then
			return Result.failure("NotReady")
		end
		return Result.success(table.freeze({
			CoinExpiresAt = record.Committed.Boosts.CoinExpiresAt,
			XpExpiresAt = record.Committed.Boosts.XpExpiresAt,
		}))
	end
	service.ApplyMutation = function(
		_self: Service.Interface,
		command: ProfileOperations.Command,
		mutator: ProfileOperations.Mutator,
		guard: ProfileOperations.Guard?
	): Result.Result<Payloads.TransactionReceipt>
		if not Transaction.validateMutation(command) then
			return Result.failure("InvalidRequest")
		end
		local record = current(command.UserId)
		if not record or record.Busy then
			return Result.failure("NotReady")
		end
		record.Busy = true
		local candidate, checkpointTime = SessionRecord.candidate(record)
		local ok, receipt = pcall(Transaction.applyMutation, candidate, command, mutator, guard)
		if not ok then
			record.Busy = false
			return Result.failure("Unavailable")
		end
		if not receipt.Ok or receipt.Value.AlreadyApplied then
			record.Busy = false
			return receipt
		end
		local outcome = commit(command.UserId, record, candidate, checkpointTime, guard)
		return if outcome.Ok then receipt else Result.failure(outcome.Code)
	end
	service.Save = function(_self: Service.Interface, userId: number): Result.Result<boolean>
		local record = current(userId)
		if not record then
			return Result.failure("NotReady")
		end
		if record.Busy then
			return Result.failure("NotReady")
		end
		record.Busy = true
		local candidate, checkpointTime = SessionRecord.candidate(record)
		return commit(userId, record, candidate, checkpointTime)
	end
	service.Release = function(_self: Service.Interface, userId: number): Result.Result<boolean>
		generations[userId] = (generations[userId] or 0) + 1
		local record = records[userId]
		if not record then
			return Result.failure("NotReady")
		end
		records[userId] = nil
		-- Explicit releases are no longer in records. Keep their checkpoint/lock
		-- drain owned so concurrent shutdown cannot release the adapter underneath it.
		jobs += 1
		local ok, outcome =
			pcall(SessionRecord.release, record, os.clock() + Config.ProfileReleaseTimeoutSeconds)
		jobs -= 1
		return if ok then outcome else Result.failure("Unavailable")
	end
	return service
end

return table.freeze(Implementation)
