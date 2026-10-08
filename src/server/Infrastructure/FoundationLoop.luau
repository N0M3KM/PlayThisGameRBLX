--!strict
-- Stub orchestration only. No votes, teleports, combat, rewards or real service calls.
-- Runtime import is unnecessary; the pure loop mirrors the canonical enum until Roblox/Lune mapping is unified.
export type State =
	"Idle"
	| "Intermission"
	| "Voting"
	| "Loading"
	| "Teleport"
	| "PreRound"
	| "Active"
	| "Resolution"
	| "Results"
export type Durations = { [string]: number }
export type Loop = {
	getState: (self: Loop) -> State,
	getRoundId: (self: Loop) -> number,
	getEndsAt: (self: Loop) -> number?,
	getErrors: (self: Loop) -> { string },
	setPlayerCount: (self: Loop, count: number) -> (),
	step: (self: Loop) -> (),
	destroy: (self: Loop) -> (),
}
local FoundationLoop = {}
local nextState: { [State]: State } = {
	Idle = "Intermission",
	Intermission = "Voting",
	Voting = "Loading",
	Loading = "Teleport",
	Teleport = "PreRound",
	PreRound = "Active",
	Active = "Resolution",
	Resolution = "Results",
	Results = "Intermission",
}

--[=[ A clock-injected foundation loop used solely for M1 stub integration. ]=]
function FoundationLoop.new(
	durations: Durations,
	clock: () -> number,
	onChanged: (State, number, number?) -> (),
	onCleanup: () -> ()
): Loop
	local state: State = "Idle"
	local roundId, playerCount = 0, 0
	local endsAt: number? = nil
	local destroyed = false
	local notifying = false
	local errors: { string } = {}
	durations = table.freeze(table.clone(durations))
	for key in nextState do
		if key ~= "Idle" then
			local duration = durations[key]
			assert(duration and duration >= 0 and duration < math.huge, `Missing/invalid duration: {key}`)
		end
	end
	local function notify(callback: () -> ())
		local outcome = table.pack(pcall(callback))
		local ok, message = outcome[1], outcome[2]
		if not ok then
			if #errors == 100 then
				table.remove(errors, 1)
			end
			table.insert(errors, tostring(message))
		end
	end
	local function enter(next: State)
		if next == "Intermission" then
			roundId += 1
		end
		state = next
		endsAt = if next == "Idle" then nil else clock() + durations[next]
		notifying = true
		if next == "Idle" or next == "Intermission" then
			notify(onCleanup)
		end
		notify(function()
			onChanged(state, roundId, endsAt)
		end)
		notifying = false
	end
	return {
		getState = function(_self: Loop): State
			return state
		end,
		getRoundId = function(_self: Loop): number
			return roundId
		end,
		getEndsAt = function(_self: Loop): number?
			return endsAt
		end,
		getErrors = function(_self: Loop): { string }
			return table.clone(errors)
		end,
		setPlayerCount = function(_self: Loop, count: number)
			assert(
				not notifying and not destroyed and count >= 0 and count % 1 == 0,
				"Invalid/reentrant player count"
			)
			playerCount = count
			if count == 0 and state ~= "Idle" then
				enter("Idle")
			end
			if count > 0 and state == "Idle" then
				enter("Intermission")
			end
		end,
		step = function(_self: Loop)
			assert(not notifying, "Cannot step inside transition callbacks")
			if destroyed or playerCount == 0 then
				return
			end
			local deadline = endsAt
			if deadline and clock() >= deadline then
				enter(nextState[state])
			end
		end,
		destroy = function(_self: Loop)
			assert(not notifying, "Cannot destroy inside transition callbacks")
			if destroyed then
				return
			end
			destroyed = true
			playerCount = 0
			enter("Idle")
		end,
	}
end
return table.freeze(FoundationLoop)
