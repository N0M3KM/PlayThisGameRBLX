--!strict
-- Pure round orchestration. The service owns scheduling, resources and authoritative participants.
local States = require("../../Contracts/States")
local Game = require("../../Config/Game")

export type Snapshot = { State: States.RoundState, RoundId: number, EndsAt: number? }
export type Options = {
	InitialRoundId: number?,
	Clock: () -> number,
	Durations: { [string]: number },
	OnEnter: (States.RoundState, number) -> (),
	OnExit: (States.RoundState, number) -> (),
	OnOutcome: (States.Outcome, number) -> (),
	BossRound: (number) -> boolean,
}
export type Machine = {
	start: () -> (),
	step: () -> (),
	abort: (States.Outcome) -> (),
	setPlayerCount: (number) -> (),
	bossDefeated: () -> (),
	getSnapshot: () -> Snapshot,
	getErrors: () -> { string },
	isRunning: () -> boolean,
	destroy: () -> (),
}

local RoundMachine = {}
local NEXT: { [States.RoundState]: States.RoundState } = table.freeze({
	Idle = "Intermission",
	Intermission = "Voting",
	Voting = "Loading",
	Loading = "Teleport",
	Teleport = "PreRound",
	PreRound = "Active",
	Active = "Resolution",
	Resolution = "Results",
	Results = "Intermission",
})
local OUTCOMES: { [string]: boolean } = table.freeze({
	Survived = true,
	NoSurvivors = true,
	BossDefeated = true,
	BossTimeout = true,
	Aborted = true,
})

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

--[=[ Callbacks must be synchronous. Mutation during any injected call is rejected.
	A callback/clock failure closes the current loop in Idle; start() explicitly resumes it.
	One outcome callback is attempted per round, including empty-server cancellation.
]=]
function RoundMachine.new(options: Options): Machine
	local durations = table.freeze(table.clone(options.Durations))
	for state in NEXT do
		if state ~= "Idle" then
			local duration = durations[state]
			assert(duration and finite(duration) and duration >= 0, `Invalid duration: {state}`)
		end
	end
	local clock, onEnter, onExit, onOutcome, bossRound =
		options.Clock, options.OnEnter, options.OnExit, options.OnOutcome, options.BossRound
	local state: States.RoundState = "Idle"
	local roundId, playerCount = options.InitialRoundId or 0, 0
	assert(finite(roundId) and roundId >= 0 and roundId % 1 == 0, "Invalid initial round ID")
	local endsAt: number? = nil
	local outcome: States.Outcome? = nil
	local isBoss, started, destroyed, busy, needsExit = false, false, false, false, false
	local lastClock = -math.huge
	local errors: { string } = {}

	local function record(message: string)
		if #errors == Game.Foundation.LogCapacity then
			table.remove(errors, 1)
		end
		table.insert(errors, string.sub(message, 1, 1000))
	end
	local function now(): number
		local value = clock()
		assert(finite(value) and value >= 0 and value >= lastClock, "Clock must be finite and monotonic")
		lastClock = value
		return value
	end
	local function emit(reason: States.Outcome)
		if outcome ~= nil or roundId == 0 then
			return
		end
		outcome = reason
		onOutcome(reason, roundId)
	end
	local function transition(nextState: States.RoundState, timestamp: number)
		if needsExit then
			needsExit = false
			onExit(state, roundId)
		end
		if nextState == "Intermission" then
			roundId += 1
			outcome, isBoss = nil, false
		end
		if nextState == "Active" then
			isBoss = bossRound(roundId)
			assert(type(isBoss) == "boolean", "BossRound must return boolean")
		end
		local duration = durations[nextState]
		if nextState == "Resolution" and outcome ~= "BossDefeated" then
			duration = 0
		end
		local deadline = if nextState == "Idle" then nil else timestamp + duration
		assert(deadline == nil or finite(deadline), "Round deadline overflow")
		state, endsAt, needsExit = nextState, deadline, true
		onEnter(state, roundId)
	end
	local function recover(message: string, closing: boolean?)
		record(message)
		started = false
		if needsExit then
			needsExit = false
			local exited = table.pack(pcall(onExit, state, roundId))
			if not exited[1] then
				record(tostring(exited[2]))
			end
		end
		state, endsAt = "Idle", nil
		if outcome == nil and roundId > 0 then
			local emitted = table.pack(pcall(emit, "Aborted" :: States.Outcome))
			if not emitted[1] then
				record(tostring(emitted[2]))
			end
		end
		if not closing then
			needsExit = true
			local entered = table.pack(pcall(onEnter, state, roundId))
			if not entered[1] then
				record(tostring(entered[2]))
			end
		end
	end
	local function mutate(callback: () -> (), closing: boolean?)
		assert(not busy, "Round mutation is forbidden during injected callbacks")
		assert(not destroyed, "Round machine is destroyed")
		busy = true
		local result = table.pack(pcall(callback))
		if not result[1] then
			recover(tostring(result[2]), closing)
		end
		busy = false
	end
	local function resolve(reason: States.Outcome, timestamp: number)
		emit(reason)
		transition("Resolution", timestamp)
	end

	return {
		start = function()
			mutate(function()
				assert(not started, "Round machine already started")
				started = true
				transition(if playerCount > 0 then "Intermission" else "Idle", now())
			end)
		end,
		step = function()
			mutate(function()
				if not started or playerCount == 0 or state == "Idle" then
					return
				end
				local timestamp, deadline = now(), endsAt
				if deadline == nil or timestamp < deadline then
					return
				end
				if state == "Active" then
					resolve(if isBoss then "BossTimeout" else "Survived", timestamp)
				elseif state == "Resolution" and (outcome == "NoSurvivors" or outcome == "Aborted") then
					transition("Intermission", timestamp)
				else
					transition(NEXT[state], timestamp)
				end
			end)
		end,
		abort = function(reason: States.Outcome)
			assert(OUTCOMES[reason], "Unknown round outcome")
			mutate(function()
				if started and state ~= "Idle" and outcome == nil then
					local timestamp = now()
					-- The boss deadline owns its exact boundary, even if the last player
					-- dies in the same scheduler turn. Earlier all-dead facts beat victory.
					local atBossDeadline = state == "Active"
						and isBoss
						and endsAt ~= nil
						and timestamp >= endsAt
					resolve(
						if reason == "NoSurvivors" and atBossDeadline then "BossTimeout" else reason,
						timestamp
					)
				elseif started and state == "Resolution" and reason == "NoSurvivors" then
					-- A celebration may end with no survivors. Keep its single settled
					-- outcome, but skip the Results screen and tear down this round.
					transition("Intermission", now())
				end
			end)
		end,
		setPlayerCount = function(count: number)
			assert(finite(count) and count >= 0 and count % 1 == 0, "Invalid player count")
			mutate(function()
				playerCount = count
				if not started then
					return
				end
				if count == 0 and state ~= "Idle" then
					emit("Aborted")
					transition("Idle", now())
				elseif count > 0 and state == "Idle" then
					transition("Intermission", now())
				end
			end)
		end,
		bossDefeated = function()
			mutate(function()
				if started and state == "Active" and isBoss and outcome == nil then
					local timestamp = now()
					local deadline = endsAt
					resolve(
						if deadline and timestamp >= deadline then "BossTimeout" else "BossDefeated",
						timestamp
					)
				end
			end)
		end,
		getSnapshot = function(): Snapshot
			return table.freeze({ State = state, RoundId = roundId, EndsAt = endsAt })
		end,
		getErrors = function(): { string }
			return table.clone(errors)
		end,
		isRunning = function(): boolean
			return started and not destroyed
		end,
		destroy = function()
			assert(not busy, "Cannot destroy during injected callbacks")
			if destroyed then
				return
			end
			mutate(function()
				started, playerCount = false, 0
				if needsExit then
					needsExit = false
					onExit(state, roundId)
				end
				if state ~= "Idle" then
					emit("Aborted")
				end
				state, endsAt = "Idle", nil
			end, true)
			destroyed, endsAt = true, nil
		end,
	}
end

return table.freeze(RoundMachine)
