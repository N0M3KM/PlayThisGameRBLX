--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Scenarios = require(Shared.Config.Scenarios)
local Payloads = require(Shared.Contracts.Payloads)
local Result = require(Shared.Contracts.Result)
local Service = require(Shared.Contracts.Service)
local Scope = require(Shared.Util.Scope)
local WeightedRandom = require(Shared.Util.WeightedRandom)
local Lifecycle = require(script.Parent.Parent.Parent.Parent.Infrastructure.ServiceLifecycle)
local Interface = require(script.Parent.Interface)

type Selection = {
	RoundId: number,
	ScenarioId: string,
	Plan: Payloads.EventPlan?,
	Bosses: { string }?,
}
local Implementation = {}

local function validRound(roundId: number): boolean
	return type(roundId) == "number" and roundId > 0 and roundId < math.huge and roundId % 1 == 0
end

--[=[ Makes one immutable scenario plan per round, retaining only the current selection. ]=]
function Implementation.new(random: Random?): Interface.Interface
	local rng = random or Random.new()
	local current: Selection? = nil
	local latestRound = 0
	local weights: { WeightedRandom.Entry } = {}
	for _, definition in Scenarios.Definitions do
		table.insert(weights, { Id = definition.Id, Weight = definition.Weight })
	end
	local facade = Lifecycle.new("ScenarioDirector", Scope.new(), {
		Stop = function()
			current = nil
		end,
	})
	local service = (facade :: unknown) :: Interface.Interface

	local function selectionError(roundId: number, scenarioId: string): Result.ErrorCode?
		if not facade:IsStarted() then
			return "NotReady"
		end
		if not validRound(roundId) or type(scenarioId) ~= "string" then
			return "InvalidRequest"
		end
		if not current then
			return if roundId <= latestRound then "StaleRound" else "WrongState"
		end
		if current.RoundId ~= roundId then
			return if roundId < current.RoundId then "StaleRound" else "WrongState"
		end
		if not Scenarios.ById[scenarioId] then
			return "UnknownId"
		end
		if current.ScenarioId ~= scenarioId then
			return "WrongState"
		end
		return nil
	end

	local function bosses(selection: Selection): { string }
		if selection.Bosses then
			return selection.Bosses
		end
		local ids: { string } = {}
		for slot = 1, Scenarios.ById[selection.ScenarioId].BossCount do
			-- Each identity is a separate instance of the single Regular-derived boss.
			table.insert(ids, `round_{selection.RoundId}_boss_{slot}`)
		end
		selection.Bosses = table.freeze(ids)
		return ids
	end

	service.SelectScenario = function(
		_self: Service.Interface,
		roundId: number,
		preferredScenarioId: string?
	): Result.Result<string>
		if not facade:IsStarted() then
			return Result.failure("NotReady")
		end
		if not validRound(roundId) then
			return Result.failure("InvalidRequest")
		end
		if preferredScenarioId ~= nil and type(preferredScenarioId) ~= "string" then
			return Result.failure("InvalidRequest")
		end
		if preferredScenarioId and not Scenarios.ById[preferredScenarioId] then
			return Result.failure("UnknownId")
		end
		if current and current.RoundId == roundId then
			if preferredScenarioId and preferredScenarioId ~= current.ScenarioId then
				return Result.failure("WrongState")
			end
			return Result.success(current.ScenarioId)
		end
		if roundId <= latestRound then
			return Result.failure("StaleRound")
		end
		local scenarioId = preferredScenarioId
			or WeightedRandom.pick(weights, function(): number
				return rng:NextNumber()
			end)
		latestRound = roundId
		current = { RoundId = roundId, ScenarioId = scenarioId }
		return Result.success(scenarioId)
	end

	service.SelectEvents = function(
		_self: Service.Interface,
		roundId: number,
		scenarioId: string
	): Result.Result<Payloads.EventPlan>
		local code: Result.ErrorCode? = selectionError(roundId, scenarioId)
		if code then
			return Result.failure(code)
		end
		local selection = current
		assert(selection, "Validated round must have a selection")
		if selection.Plan then
			return Result.success(selection.Plan)
		end
		local definition = Scenarios.ById[scenarioId]
		local instances: { Payloads.EventInstance } = {}
		local function addSlots(category: string, minimum: number, maximum: number)
			for slot = 1, rng:NextInteger(minimum, maximum) do
				-- The draft Tornado-only policy repeats instances to preserve configured counts.
				local instance: Payloads.EventInstance = {
					InstanceId = `round_{roundId}_{category}_{slot}`,
					DefinitionId = "tornado",
					RoundId = roundId,
				}
				table.insert(instances, table.freeze(instance))
			end
		end
		addSlots("event", definition.EventMinimum, definition.EventMaximum)
		addSlots("disaster", definition.DisasterMinimum, definition.DisasterMaximum)
		local plan: Payloads.EventPlan = {
			RoundId = roundId,
			Instances = table.freeze(instances),
			BossInstanceIds = bosses(selection),
		}
		selection.Plan = table.freeze(plan)
		return Result.success(plan)
	end

	service.SelectBosses = function(
		_self: Service.Interface,
		roundId: number,
		scenarioId: string
	): Result.Result<{ string }>
		local code: Result.ErrorCode? = selectionError(roundId, scenarioId)
		if code then
			return Result.failure(code)
		end
		local selection = current
		assert(selection, "Validated round must have a selection")
		return Result.success(bosses(selection))
	end
	return service
end

return table.freeze(Implementation)
