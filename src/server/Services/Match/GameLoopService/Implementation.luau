--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Service = require(Shared.Contracts.Service)
local Domain = require(Shared.Contracts.DomainInterfaces)
local States = require(Shared.Contracts.States)
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Game = require(Shared.Config.Game)
local Config = require(Shared.Config.Match)
local Scope = require(Shared.Util.Scope)
local Validation = require(Shared.Registry.Validation)
local Machine = require(script.Parent.RoundMachine)
local Session = require(script.Parent.MatchSession)
local Results = require(Shared.Util.Match.ResultsCalculator)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Interface = require(script.Parent.Interface)
local Implementation = {}
export type Loop =
	Interface.Interface
	& { ReportBossDeath: (Service.Interface, number, string) -> Result.Result<boolean> }

--[=[ One owned scheduler drives the match. Cross-domain effects consume the published context later. ]=]
function Implementation.new(
	resolve: (string) -> Service.Interface,
	random: Random,
	changed: (Payloads.MatchSnapshot, number) -> (),
	ended: (Results.Result) -> ()
): Loop
	local scope = Scope.new()
	local runScope: Scope.Scope? = nil
	local machine: Machine.Machine? = nil
	local session: Session.Session? = nil
	local revision = 0
	local latestRoundId = 0
	local ticking = false
	local pendingStop = false
	local tickStartedAt = 0
	local watchdogCanceled = false
	local bossReports: { [string]: number } = {}
	local result: Loop
	local function snapshot(): Payloads.MatchSnapshot
		local current: Machine.Snapshot = if machine
			then machine.getSnapshot()
			else { State = "Idle", RoundId = latestRoundId, EndsAt = nil }
		return table.freeze({
			ContractVersion = Payloads.Version,
			Revision = revision,
			State = current.State :: States.RoundState,
			RoundId = current.RoundId,
			EndsAt = current.EndsAt,
			MapId = if session then session.mapId() else nil,
			ScenarioId = if session then session.scenarioId() else nil,
		})
	end
	local function publish()
		if machine then
			latestRoundId = math.max(latestRoundId, machine.getSnapshot().RoundId)
		end
		revision += 1
		changed(snapshot(), if session then session.aliveCount() else 0)
	end
	local function finalizeStop()
		local previousMachine, previousSession, previousScope = machine, session, runScope
		if previousMachine then
			latestRoundId = math.max(latestRoundId, previousMachine.getSnapshot().RoundId)
		end
		runScope, machine, session = nil, nil, nil
		table.clear(bossReports)
		-- A failing outcome/return-to-lobby hook must not prevent the remaining
		-- ownership boundaries from being destroyed during shutdown.
		local function clean(callback: () -> ())
			local cleaned = table.pack(pcall(callback))
			if not cleaned[1] then
				warn(`Match stop failed: {tostring(cleaned[2])}`)
			end
		end
		if previousMachine then
			clean(previousMachine.destroy)
		end
		if previousSession then
			clean(previousSession.cleanup)
		end
		if previousScope then
			for _, message in previousScope:destroy() do
				warn(`Match cleanup failed: {message}`)
			end
		end
		pendingStop = false
		revision += 1
		local published = table.pack(pcall(changed, snapshot(), 0))
		if not published[1] then
			warn(`Match stopped-state publication failed: {tostring(published[2])}`)
		end
	end
	local function stop()
		pendingStop = true
		if machine then
			local teleport = (resolve("TeleportService") :: unknown) :: Domain.TeleportService
			local ok, message = pcall(teleport.Cancel, teleport, machine.getSnapshot().RoundId)
			if not ok then
				warn(`Match teleport cancellation failed: {tostring(message)}`)
			end
		end
		if not ticking then
			finalizeStop()
		end
	end
	local function start()
		assert(not ticking and runScope == nil, "Previous match run must finish stopping before restart")
		local owned = scope:child()
		runScope = owned
		local activeSession = Session.new(resolve, random, owned, ended)
		session = activeSession
		local activeMachine = Machine.new({
			InitialRoundId = latestRoundId,
			Clock = function()
				return Workspace:GetServerTimeNow()
			end,
			Durations = {
				Intermission = Game.IntermissionSeconds,
				Voting = Game.VotingSeconds,
				Loading = Game.LoadingSeconds,
				Teleport = 0,
				PreRound = Game.PreRoundSeconds,
				Active = Game.RoundDurationSeconds,
				Resolution = Game.BossCelebrationSeconds,
				Results = Game.ResultsSeconds,
			},
			OnEnter = function(state, roundId)
				assert(machine, "Match machine must exist")
				activeSession.enter(state, roundId, machine.getSnapshot().EndsAt)
				publish()
			end,
			OnExit = function(_state, _roundId) end,
			OnOutcome = activeSession.resolve,
			BossRound = function(_roundId)
				return activeSession.isBoss()
			end,
		})
		machine = activeMachine
		activeMachine.setPlayerCount(activeSession.count("Idle"))
		local bossCoordinator = (resolve("BossCoordinator") :: unknown) :: Domain.BossCoordinator
		owned:add(bossCoordinator:ObserveDeaths(function(roundId, instanceId)
			if runScope == owned and not owned:isDestroyed() then
				result:ReportBossDeath(roundId, instanceId)
			end
		end))
		tickStartedAt, watchdogCanceled = Workspace:GetServerTimeNow(), false
		ticking = true
		activeMachine.start()
		ticking = false
		if pendingStop then
			finalizeStop()
			return
		end
		local elapsed = 0
		local warned = 0
		local retries, retryAfter = 0, 0
		local connection = RunService.Heartbeat:Connect(function(deltaTime)
			if runScope ~= owned or owned:isDestroyed() then
				return
			end
			if ticking then
				if
					not watchdogCanceled
					and Workspace:GetServerTimeNow() - tickStartedAt > Config.LoadingWatchdogSeconds
				then
					watchdogCanceled = true
					local teleport = resolve("TeleportService")
					local cancel = ((teleport :: unknown) :: {
						Cancel: (Service.Interface, number) -> Result.Result<boolean>,
					}).Cancel
					local ok, message = pcall(cancel, teleport, activeMachine.getSnapshot().RoundId)
					if not ok then
						warn(`Match watchdog cancellation failed: {tostring(message)}`)
					end
				end
				return
			end
			if pendingStop or not result:IsStarted() then
				return
			end
			elapsed += deltaTime
			if elapsed < Config.TickSeconds then
				return
			end
			elapsed %= Config.TickSeconds
			ticking = true
			tickStartedAt, watchdogCanceled = Workspace:GetServerTimeNow(), false
			local outcome = table.pack(pcall(function()
				if retries > Config.RecoveryRetryCount or tickStartedAt < retryAfter then
					return
				end
				local current = activeMachine.getSnapshot()
				if
					not activeMachine.isRunning()
					and retries < Config.RecoveryRetryCount
					and Workspace:GetServerTimeNow() >= retryAfter
					and activeSession.count("Idle") > 0
				then
					retries += 1
					retryAfter = Workspace:GetServerTimeNow() + Config.RecoveryDelaySeconds
					activeMachine.start()
					current = activeMachine.getSnapshot()
				end
				-- Active participants, rather than only living players, own the empty-server rule.
				activeMachine.setPlayerCount(activeSession.count(current.State))
				current = activeMachine.getSnapshot()
				if current.State == "Voting" then
					activeSession.padVotes()
				end
				if
					(current.State == "Active" or current.State == "Resolution")
					and activeSession.aliveCount() == 0
				then
					activeMachine.abort("NoSurvivors")
				end
				-- Integration may report boss deaths synchronously inside OnEnter.
				-- Consume their IDs only after that mutation finishes; all-dead is
				-- evaluated first and the machine enforces its exact deadline.
				for instanceId, expectedRound in bossReports do
					bossReports[instanceId] = nil
					if expectedRound == activeMachine.getSnapshot().RoundId then
						if activeSession.bossDied(expectedRound, instanceId) then
							activeMachine.bossDefeated()
						end
					end
				end
				current = activeMachine.getSnapshot()
				if current.State == "Teleport" and not activeSession.teleportReady() then
					local failure = activeSession.teleportError()
					if
						failure
						or (
							current.EndsAt
							and Workspace:GetServerTimeNow() - current.EndsAt
								> Config.LoadingWatchdogSeconds
						)
					then
						warn(failure or "Teleport watchdog expired")
						activeMachine.abort("Aborted")
					end
				else
					activeMachine.step()
				end
				assert(not watchdogCanceled, "Match scheduler exceeded the loading watchdog")
				publish()
			end))
			ticking = false
			if not outcome[1] then
				warn(`Match scheduler failed: {tostring(outcome[2])}`)
				retries += 1
				retryAfter = Workspace:GetServerTimeNow() + Config.RecoveryDelaySeconds
				-- Errors outside the machine callbacks also abandon ownership. Idle
				-- entry releases the failed round before any next attempt.
				local recovered = table.pack(pcall(activeMachine.setPlayerCount, 0))
				if not recovered[1] then
					warn(`Match recovery failed: {tostring(recovered[2])}`)
					pendingStop = true
				end
			end
			local errors = activeMachine.getErrors()
			if #errors > warned then
				warned = #errors
				warn(`Match recovered to Idle: {errors[#errors]}`)
			end
			if pendingStop then
				finalizeStop()
			end
		end)
		owned:add(function()
			connection:Disconnect()
		end)
	end
	local function mutate(callback: () -> ()): Result.Result<boolean>
		tickStartedAt, watchdogCanceled = Workspace:GetServerTimeNow(), false
		ticking = true
		local mutated = table.pack(pcall(function()
			callback()
			publish()
		end))
		ticking = false
		if pendingStop then
			finalizeStop()
		end
		if not mutated[1] then
			warn(`Match command failed: {tostring(mutated[2])}`)
			return Result.failure("Unavailable")
		end
		return Result.success(true)
	end
	result = (
		Lifecycle.new("GameLoopService", scope, {
			Start = function()
				local previousRun = runScope
				local started = table.pack(pcall(start))
				if not started[1] then
					if runScope ~= previousRun then
						ticking = false
						finalizeStop()
					end
					error(tostring(started[2]), 0)
				end
			end,
			Stop = stop,
		}) :: unknown
	) :: Loop
	result.GetState = function(_self: Service.Interface): Result.Result<Payloads.MatchSnapshot>
		return Result.success(snapshot())
	end
	result.Advance = function(self: Service.Interface, expectedRound: number): Result.Result<boolean>
		if not self:IsStarted() or not machine then
			return Result.failure("NotReady")
		end
		if machine.getSnapshot().RoundId ~= expectedRound then
			return Result.failure("StaleRound")
		end
		if ticking then
			return Result.failure("WrongState")
		end
		if machine.getSnapshot().State == "Teleport" and session and not session.teleportReady() then
			return Result.failure("WrongState")
		end
		local activeMachine = machine
		local activeSession = session
		return mutate(function()
			local state = activeMachine.getSnapshot().State
			if
				activeSession
				and (state == "Active" or state == "Resolution")
				and activeSession.aliveCount() == 0
			then
				activeMachine.abort("NoSurvivors")
			end
			activeMachine.step()
		end)
	end
	result.Abort = function(
		self: Service.Interface,
		expectedRound: number,
		reason: string
	): Result.Result<boolean>
		if not self:IsStarted() or not machine then
			return Result.failure("NotReady")
		end
		if expectedRound ~= machine.getSnapshot().RoundId then
			return Result.failure("StaleRound")
		end
		if ticking then
			return Result.failure("WrongState")
		end
		if reason ~= "Aborted" and reason ~= "NoSurvivors" then
			return Result.failure("InvalidRequest")
		end
		local activeMachine = machine
		return mutate(function()
			activeMachine.abort(reason :: States.Outcome)
			if reason == "Aborted" then
				-- Cancellation is valid even after settlement (Results/celebration).
				-- This enters Idle and cleans ownership without emitting a second result.
				activeMachine.setPlayerCount(0)
			end
		end)
	end
	result.ReportBossDeath = function(
		self: Service.Interface,
		expectedRound: number,
		instanceId: string
	): Result.Result<boolean>
		if not self:IsStarted() or not machine or not session then
			return Result.failure("NotReady")
		end
		if expectedRound ~= machine.getSnapshot().RoundId then
			return Result.failure("StaleRound")
		end
		if not Validation.id(instanceId) then
			return Result.failure("InvalidRequest")
		end
		if machine.getSnapshot().State ~= "Active" then
			return Result.failure("WrongState")
		end
		if ticking then
			bossReports[instanceId] = expectedRound
			return Result.success(true)
		end
		local completed = session.bossDied(expectedRound, instanceId)
		if completed == nil then
			return Result.failure("UnknownId")
		end
		if completed then
			local activeMachine, activeSession = machine, session
			return mutate(function()
				if activeSession.aliveCount() == 0 then
					activeMachine.abort("NoSurvivors")
				else
					activeMachine.bossDefeated()
				end
			end)
		end
		return Result.success(true)
	end
	return result
end
return table.freeze(Implementation)
