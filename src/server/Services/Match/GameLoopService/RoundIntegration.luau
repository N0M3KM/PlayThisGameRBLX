--!strict
-- Cross-domain effects resolve published interfaces; no implementation imports.
local Shared = game:GetService("ReplicatedStorage").Shared
local Domain = require(Shared.Contracts.DomainInterfaces)
local Payloads = require(Shared.Contracts.Payloads)
local Service = require(Shared.Contracts.Service)
local Result = require(Shared.Contracts.Result)
local Maps = require(Shared.Config.Maps)
local Scenarios = require(Shared.Config.Scenarios)

local RoundIntegration = {}
export type Integration = {
	takePick: (number, { number }) -> Payloads.PickSelection?,
	prepare: (number, { number }) -> { number },
	grant: (number, { number }) -> (),
	start: (number, string, Payloads.EventPlan) -> (),
	stop: (number) -> (),
	cleanup: (number) -> (),
	stats: (number) -> { Payloads.RoundStat },
	settle: (Payloads.RoundOutcome) -> (),
}

--[=[ Preview skips only deliberate stubs. Real service errors fail the round closed.
	Production requires ready domain services before locking or teleporting players.
]=]
function RoundIntegration.new(resolve: (string) -> Service.Interface, preview: boolean): Integration
	local data = (resolve("DataService") :: unknown) :: Domain.DataService
	local loadout = (resolve("LoadoutService") :: unknown) :: Domain.LoadoutService
	local damage = (resolve("DamageService") :: unknown) :: Domain.DamageService
	local droids = (resolve("DroidService") :: unknown) :: Domain.DroidService
	local events = (resolve("EventService") :: unknown) :: Domain.EventService
	local bosses = (resolve("BossCoordinator") :: unknown) :: Domain.BossCoordinator
	local brains = (resolve("DroidBrainHost") :: unknown) :: Domain.DroidBrainHost
	local projectiles = (resolve("ProjectileService") :: unknown) :: Domain.ProjectileService
	local economy = (resolve("EconomyService") :: unknown) :: Domain.EconomyService
	local picks = (resolve("PickQueue") :: unknown) :: Domain.PickQueue
	local locked: { [number]: boolean } = {}
	local selection: Payloads.PickSelection? = nil
	local activated = false
	local stopped = false
	local function skipped(service: Service.Interface): boolean
		return preview and service.IsStub
	end
	local function requireReady(service: Service.Interface)
		assert(not service.IsStub and service:IsStarted(), `{service.Name} is not ready`)
	end
	local function accepted<T>(response: Result.Result<T>, operation: string): T
		if not response.Ok then
			error(`{operation} failed: {response.Code}`)
		end
		return response.Value
	end
	local function command(response: Result.Result<boolean>, operation: string)
		assert(accepted(response, operation), `{operation} was not applied`)
	end
	local function safely(label: string, callback: () -> ())
		local called = table.pack(pcall(callback))
		if not called[1] then
			warn(`Round cleanup {label}: {tostring(called[2])}`)
		end
	end
	local function stop(roundId: number)
		if stopped then
			return
		end
		stopped = true
		if not skipped(events) then
			safely("events", function()
				command(events:StopAll(roundId), "StopAll")
			end)
		end
		if not skipped(bosses) then
			safely("bosses", function()
				command(bosses:StopRound(roundId), "Boss StopRound")
			end)
		end
		if not skipped(droids) then
			safely("droids", function()
				command(droids:StopRound(roundId), "Droid StopRound")
			end)
		end
		if not skipped(brains) then
			safely("brains", function()
				command(brains:StopRound(roundId), "Brain StopRound")
			end)
		end
		if not skipped(projectiles) then
			safely("projectiles", function()
				command(projectiles:CancelRound(roundId), "CancelRound")
			end)
		end
	end
	return {
		takePick = function(roundId: number, eligible: { number }): Payloads.PickSelection?
			activated, stopped, selection = false, false, nil
			if not preview then
				local dependencies: { Service.Interface } =
					{ data, loadout, damage, droids, events, bosses, brains, projectiles, economy, picks }
				for _, dependency in dependencies do
					requireReady(dependency)
				end
			end
			if skipped(picks) then
				return nil
			end
			selection = accepted(picks:TakeNextEligible(roundId, eligible), "TakeNextEligible")
			if selection then
				assert(Maps.ById[selection.MapId], "Pick selection has an unknown map")
				assert(Scenarios.ById[selection.ScenarioId], "Pick selection has an unknown scenario")
			end
			return selection
		end,
		prepare = function(roundId: number, eligible: { number }): { number }
			local prepared: { number } = {}
			for _, userId in eligible do
				local profileReady = skipped(data) or data:Read(userId).Ok
				if profileReady then
					if not skipped(loadout) then
						-- Mark ownership before calling: a failing implementation may have partially locked.
						locked[userId] = true
						local snapshot = accepted(loadout:SnapshotAndLock(userId, roundId), "SnapshotAndLock")
						assert(
							snapshot.UserId == userId and snapshot.RoundId == roundId,
							"Stale loadout snapshot"
						)
					end
					table.insert(prepared, userId)
				end
			end
			return prepared
		end,
		grant = function(roundId: number, participants: { number })
			local retained: { [number]: boolean } = {}
			for _, userId in participants do
				retained[userId] = true
				if not skipped(loadout) then
					command(loadout:Grant(userId, roundId), "Grant")
				end
			end
			for userId in locked do
				if not retained[userId] then
					command(loadout:Clear(userId), "Clear excluded player")
					command(loadout:Unlock(userId, roundId), "Unlock excluded player")
					locked[userId] = nil
				end
			end
		end,
		start = function(roundId: number, mapId: string, plan: Payloads.EventPlan)
			assert(plan.RoundId == roundId, "Stale event plan")
			if not skipped(damage) then
				command(damage:BeginRound(roundId), "Damage BeginRound")
			end
			if not skipped(droids) then
				command(droids:StartSpawning(roundId, mapId), "StartSpawning")
			end
			if not skipped(events) then
				command(events:StartPlan(plan), "StartPlan")
			end
			if not skipped(bosses) and #plan.BossInstanceIds > 0 then
				local spawned = accepted(bosses:SpawnRequired(roundId, plan.BossInstanceIds), "SpawnRequired")
				local expected: { [string]: boolean } = {}
				for _, id in plan.BossInstanceIds do
					expected[id] = true
				end
				for _, boss in spawned do
					assert(
						expected[boss.InstanceId] and boss.Entity.RoundId == roundId,
						"Unexpected boss instance"
					)
					expected[boss.InstanceId] = nil
				end
				assert(next(expected) == nil, "Required boss instances were not all spawned")
			end
			activated = true
		end,
		stop = stop,
		cleanup = function(roundId: number)
			stop(roundId)
			for userId in locked do
				safely("clear loadout", function()
					command(loadout:Clear(userId), "Clear")
				end)
				safely("unlock loadout", function()
					command(loadout:Unlock(userId, roundId), "Unlock")
				end)
			end
			table.clear(locked)
			-- Results consume the ledger before session cleanup releases its round.
			if not skipped(damage) then
				safely("damage ledger", function()
					command(damage:ClearRound(roundId), "Damage ClearRound")
				end)
			end
			if selection and not activated then
				local restore = selection
				safely("restore pick", function()
					command(picks:Restore(restore), "Restore")
				end)
			end
			selection = nil
		end,
		stats = function(roundId: number): { Payloads.RoundStat }
			return if skipped(damage) then {} else accepted(damage:GetRoundStats(roundId), "GetRoundStats")
		end,
		settle = function(outcome: Payloads.RoundOutcome)
			if not preview then
				accepted(economy:SettleSurvival(outcome), "SettleSurvival")
			end
		end,
	}
end

return table.freeze(RoundIntegration)
