--!strict
-- Round orchestration consumes interfaces; the preview never grants currency or persists defaults.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Domain = require(Shared.Contracts.DomainInterfaces)
local Result = require(Shared.Contracts.Result)
local States = require(Shared.Contracts.States)
local Service = require(Shared.Contracts.Service)
local Scope = require(Shared.Util.Scope)
local Config = require(Shared.Config.Match)
local Maps = require(Shared.Config.Maps)
local Scenarios = require(Shared.Config.Scenarios)
local Results = require(Shared.Util.Match.ResultsCalculator)
local Integration = require(script.Parent.RoundIntegration)
local ResultsCalculator = require(script.Parent.Parent.ResultsCalculator)
local WeightedRandom = require(Shared.Util.WeightedRandom)
local Session = {}
export type Session = {
	enter: (States.RoundState, number, number?) -> (),
	cleanup: () -> (),
	resolve: (States.Outcome, number) -> (),
	count: (States.RoundState) -> number,
	aliveCount: () -> number,
	mapId: () -> string?,
	scenarioId: () -> string?,
	isBoss: () -> boolean,
	bossDied: (number, string) -> boolean?,
	voteChoices: () -> { string },
	padVotes: () -> (),
	teleportReady: () -> boolean,
	teleportError: () -> string?,
}

function Session.new(
	resolve: (string) -> Service.Interface,
	random: Random,
	scope: Scope.Scope,
	ended: (Results.Result) -> ()
): Session
	local maps = (resolve("MapService") :: unknown) :: Domain.MapService
	local players = (resolve("PlayerStateService") :: unknown) :: Domain.PlayerStateService
	local teleports = (resolve("TeleportService") :: unknown) :: Domain.TeleportService
	local voting = (resolve("VotingService") :: unknown) :: Domain.VotingService
	local scenarios = (resolve("ScenarioDirector") :: unknown) :: Domain.ScenarioDirector
	local integration = Integration.new(resolve, Config.PreviewOnly)
	local emitResult = ResultsCalculator.new(integration, Config.PreviewOnly, ended)
	local pickMap: string? = nil
	local roundId, ownedRound = 0, 0
	local mapId: string? = nil
	local scenarioId: string? = nil
	local choices: { string } = {}
	local participants: { number } = {}
	local pendingBosses: { [string]: boolean } = {}
	local outcome: States.Outcome? = nil
	local emitted = false
	local roundScope: Scope.Scope? = nil
	local resourcesCleaned = false
	local teleportReady = false
	local teleportFailure: string? = nil
	local function alive(): { number }
		local result = players:GetAlive(roundId)
		return if result.Ok then result.Value else {}
	end
	local function emit()
		if emitted or not outcome or ownedRound == 0 then
			return
		end
		emitted = true
		local called = table.pack(pcall(emitResult, ownedRound, outcome, participants, alive()))
		if not called[1] then
			warn(`Round results unavailable; round not settled: {tostring(called[2])}`)
		end
	end
	local function safely(label: string, callback: () -> ())
		local called = table.pack(pcall(callback))
		if not called[1] then
			warn(`Match cleanup {label}: {tostring(called[2])}`)
		end
	end
	local function cleanup(keepParticipants: boolean?)
		if ownedRound == 0 then
			return
		end
		if not resourcesCleaned then
			resourcesCleaned = true
			safely("voting", function()
				voting:Close()
			end)
			safely("teleport cancellation", function()
				teleports:Cancel(ownedRound)
			end)
			local ownedScope = roundScope
			roundScope = nil
			if ownedScope then
				safely("scope", function()
					ownedScope:destroy()
				end)
			end
			safely("domains", function()
				integration.cleanup(ownedRound)
			end)
			for _, userId in participants do
				safely(`lobby return {userId}`, function()
					local snapshot = players:Get(userId)
					if snapshot.Ok then
						local moved = teleports:ToLobby(userId, snapshot.Value.CharacterGeneration)
						if not moved.Ok then
							warn(`Lobby return {userId}: {moved.Code}`)
						end
					end
				end)
			end
			safely("player reset", function()
				players:ResetRound(ownedRound)
			end)
			safely("map unload", function()
				local unloaded = maps:Unload(ownedRound)
				if not unloaded.Ok then
					warn(`Map unload: {unloaded.Code}`)
				end
			end)
		end
		if keepParticipants then
			return
		end
		ownedRound, participants = 0, {}
		teleportReady, teleportFailure = false, nil
		mapId, scenarioId, pickMap, choices = nil, nil, nil, {}
		table.clear(pendingBosses)
	end
	local function enter(state: States.RoundState, nextRound: number, deadline: number?)
		if state == "Idle" or state == "Intermission" then
			emit()
			cleanup()
		end
		roundId = nextRound
		if state == "Intermission" then
			ownedRound, emitted, outcome = roundId, false, nil
			resourcesCleaned = false
			roundScope = scope:child()
			local pick = integration.takePick(roundId, players:EligiblePlayers())
			pickMap = if pick then pick.MapId else nil
			local selected = scenarios:SelectScenario(roundId, if pick then pick.ScenarioId else nil)
			assert(selected.Ok, "Scenario selection failed")
			scenarioId = selected.Value
		elseif state == "Voting" then
			choices = {}
			if pickMap then
				table.insert(choices, pickMap)
			else
				local weighted: { WeightedRandom.Entry } = {}
				for _, definition in Maps.Definitions do
					table.insert(weighted, { Id = definition.Id, Weight = definition.SpawnWeight })
				end
				choices = WeightedRandom.withoutReplacement(weighted, 3, function(): number
					return random:NextNumber()
				end)
			end
			assert(deadline, "Voting requires a deadline")
			local opened = voting:Open(roundId, choices, deadline)
			assert(opened.Ok, "Voting could not open")
		elseif state == "Loading" then
			local selected = voting:Resolve(roundId)
			assert(selected.Ok, "Voting resolution failed")
			local selectedMap = selected.Value
			mapId = selectedMap
			local loaded = maps:Load(roundId, selectedMap)
			assert(loaded.Ok, "Selected map could not load")
		elseif state == "Teleport" then
			assert(mapId, "Teleport requires a loaded map")
			local prepared = integration.prepare(roundId, players:EligiblePlayers())
			local eligible = players:BeginRound(roundId, prepared)
			participants = table.clone(eligible)
			local expectedRound, selectedMap, owner = roundId, mapId, roundScope
			assert(owner, "Teleport requires a round scope")
			local thread = task.defer(function()
				local called =
					table.pack(pcall(teleports.ToMap, teleports, expectedRound, selectedMap, eligible))
				if owner:isDestroyed() or roundId ~= expectedRound then
					return
				end
				if not called[1] then
					teleportFailure = tostring(called[2])
					return
				end
				local moved = (called[2] :: unknown) :: Result.Result<{ number }>
				if not moved.Ok or #moved.Value == 0 then
					teleportFailure = "No eligible players could be teleported"
					return
				end
				participants = moved.Value
				for _, userId in eligible do
					if not table.find(participants, userId) then
						local current = players:Get(userId)
						if current.Ok and current.Value.State == "InRound" then
							players:Transition(
								userId,
								"InRound",
								"Lobby",
								expectedRound,
								current.Value.CharacterGeneration
							)
						end
					end
				end
				teleportReady = true
			end)
			owner:add(function()
				if coroutine.status(thread) == "suspended" then
					task.cancel(thread)
				end
			end)
		elseif state == "PreRound" then
			integration.grant(roundId, participants)
		elseif state == "Active" then
			assert(scenarioId, "Round requires a scenario")
			assert(mapId, "Round requires a loaded map")
			local plan = scenarios:SelectEvents(roundId, scenarioId)
			assert(plan.Ok, "Round plan is unavailable")
			for _, id in plan.Value.BossInstanceIds do
				pendingBosses[id] = true
			end
			integration.start(roundId, mapId, plan.Value)
		elseif state == "Resolution" then
			integration.stop(roundId)
		elseif state == "Results" then
			emit()
			-- Capture final survivors first, then present Results from the lobby.
			cleanup(true)
		end
	end
	return {
		enter = enter,
		cleanup = cleanup,
		resolve = function(reason: States.Outcome, expectedRound: number)
			if expectedRound ~= roundId or outcome then
				return
			end
			outcome = reason
			if reason == "BossTimeout" and not Config.PreviewOnly then
				for _, userId in alive() do
					local player = Players:GetPlayerByUserId(userId)
					local humanoid = if player and player.Character
						then player.Character:FindFirstChildOfClass("Humanoid")
						else nil
					if humanoid then
						humanoid.Health = 0
					end
				end
			end
		end,
		count = function(state: States.RoundState): number
			if state == "Idle" or state == "Intermission" or state == "Voting" or state == "Loading" then
				return #players:EligiblePlayers()
			end
			local count = 0
			for _, id in participants do
				if Players:GetPlayerByUserId(id) then
					count += 1
				end
			end
			return count
		end,
		aliveCount = function(): number
			return #alive()
		end,
		mapId = function(): string?
			return mapId
		end,
		scenarioId = function(): string?
			return scenarioId
		end,
		isBoss = function(): boolean
			return scenarioId ~= nil and Scenarios.ById[scenarioId].BossCount > 0
		end,
		bossDied = function(expectedRound: number, instanceId: string): boolean?
			if expectedRound ~= roundId or not pendingBosses[instanceId] then
				return nil
			end
			pendingBosses[instanceId] = nil
			return next(pendingBosses) == nil
		end,
		voteChoices = function(): { string }
			return table.clone(choices)
		end,
		teleportReady = function(): boolean
			return teleportReady
		end,
		teleportError = function(): string?
			return teleportFailure
		end,
		padVotes = function()
			local lobby = game:GetService("Workspace"):FindFirstChild("MatchLobby")
			local pads = if lobby then lobby:FindFirstChild("VotePads") else nil
			if not pads then
				return
			end
			for _, userId in players:EligiblePlayers() do
				local player = Players:GetPlayerByUserId(userId)
				local root = if player and player.Character
					then player.Character:FindFirstChild("HumanoidRootPart")
					else nil
				if root and root:IsA("BasePart") then
					for index, id in choices do
						local pad = pads:FindFirstChild(`Pad{index}`)
						if pad and pad:IsA("BasePart") then
							local point = pad.CFrame:PointToObjectSpace(root.Position)
							if
								math.abs(point.X) <= pad.Size.X / 2
								and math.abs(point.Z) <= pad.Size.Z / 2
								and math.abs(point.Y) <= Config.ZoneHeightTolerance
							then
								voting:Cast(userId, roundId, id)
								break
							end
						end
					end
				end
			end
		end,
	}
end
return table.freeze(Session)
