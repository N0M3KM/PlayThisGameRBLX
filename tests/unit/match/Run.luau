--!strict
-- Pure regressions only; these do not establish Studio, physics or multiplayer evidence.
local RoundMachine = require("../../../src/shared/Util/Match/RoundMachine")
local VoteLedger = require("../../../src/shared/Util/Match/VoteLedger")
local Results = require("../../../src/shared/Util/Match/ResultsCalculator")
local Validation = require("../../../src/shared/Registry/Validation")
local Limits = require("../../../src/shared/Config/Validation")
local States = require("../../../src/shared/Contracts/States")

local passed = 0
local currentTest = "Match"
local function expect(condition: boolean, message: string?)
	assert(condition, message or currentTest)
end
local function test(name: string, callback: () -> ())
	currentTest = name
	local outcome = table.pack(pcall(callback))
	expect(outcome[1], `{name}: {tostring(outcome[2])}`)
	passed += 1
	print(`PASS {name}`)
end
local function rejects(callback: () -> ())
	expect(not pcall(callback), "Expected rejection")
end

type Fixture = {
	Machine: RoundMachine.Machine,
	Outcomes: { States.Outcome },
	setTime: (number) -> (),
}
local function machineFixture(boss: boolean, initialRoundId: number?): Fixture
	local time = 0
	local outcomes: { States.Outcome } = {}
	local machine = RoundMachine.new({
		InitialRoundId = initialRoundId,
		Clock = function()
			return time
		end,
		Durations = {
			Intermission = 0,
			Voting = 0,
			Loading = 0,
			Teleport = 0,
			PreRound = 0,
			Active = 240,
			Resolution = 10,
			Results = 10,
		},
		OnEnter = function(_state, _roundId) end,
		OnExit = function(_state, _roundId) end,
		OnOutcome = function(reason, _roundId)
			table.insert(outcomes, reason)
		end,
		BossRound = function(_roundId)
			return boss
		end,
	})
	machine.setPlayerCount(1)
	machine.start()
	return {
		Machine = machine,
		Outcomes = outcomes,
		setTime = function(value)
			time = value
		end,
	}
end
local function enterActive(fixture: Fixture)
	for _ = 1, 5 do
		fixture.Machine.step()
	end
	expect(fixture.Machine.getSnapshot().State == "Active")
end
local function ledger(): VoteLedger.Ledger
	return VoteLedger.new(function(minimum, _maximum)
		return minimum
	end)
end
local function resultOptions(userId: number): Results.Options
	return {
		RoundId = 1,
		Reason = "Survived",
		Participants = { userId },
		Alive = { userId },
		Stats = {},
		PreviewOnly = true,
	}
end

test("player identity accepts Studio IDs and rejects invalid bounded integers", function()
	for _, userId in { -Limits.MaxInteger, -1, 1, Limits.MaxInteger } do
		expect(Validation.playerId(userId, Limits.MaxInteger))
	end
	for _, userId in
		{ 0, 0.5, -0.5, 0 / 0, math.huge, -math.huge, Limits.MaxInteger + 1, -Limits.MaxInteger - 1 }
	do
		expect(not Validation.playerId(userId, Limits.MaxInteger))
	end
	expect(not Validation.playerId("1", Limits.MaxInteger))
	expect(not Validation.playerId({}, Limits.MaxInteger))
end)

test("sticky votes switch atomically and snapshots cannot mutate the ledger", function()
	local votes = ledger()
	expect(votes:open(1, { "map_a", "map_b" }, 10).Ok)
	expect(votes:cast(-1, 1, "map_a", 1).Ok)
	local repeated = votes:cast(-1, 1, "map_a", 2)
	expect(repeated.Ok and repeated.Value == false)
	local before = votes:snapshot()
	expect(before.Counts.map_a == 1 and before.Counts.map_b == 0)
	expect(votes:cast(-1, 1, "map_b", 3).Ok)
	local switched = votes:snapshot()
	expect(switched.Counts.map_a == 0 and switched.Counts.map_b == 1)
	expect(before.Counts.map_a == 1 and before.Counts.map_b == 0)
	rejects(function()
		switched.Counts.map_b = 20
	end)
	expect(votes:removePlayer(-1).Ok)
	expect(votes:snapshot().Counts.map_b == 0)
end)

test("vote deadline closes casting and resolution happens once", function()
	local votes = ledger()
	expect(votes:open(1, { "map_a", "map_b" }, 10).Ok)
	expect(votes:cast(42, 1, "map_b", 9).Ok)
	expect(not votes:resolve(1, 9).Ok)
	expect(not votes:cast(42, 1, "map_a", 10).Ok)
	local winner = votes:resolve(1, 10)
	expect(winner.Ok and winner.Value == "map_b")
	expect(votes:snapshot().Deadline == nil)
	expect(not votes:resolve(1, 10).Ok)
	expect(not votes:cast(42, 1, "map_a", 11).Ok)
	expect(votes:open(2, { "map_a", "map_b" }, 20).Ok)
	expect(votes:snapshot().Counts.map_b == 0)
end)

test("invalid vote intents preserve existing votes", function()
	local votes = ledger()
	expect(votes:open(1, { "map_a", "map_b" }, 10).Ok)
	expect(votes:cast(42, 1, "map_a", 1).Ok)
	for _, userId in { 0, 0.5, 0 / 0, math.huge, Limits.MaxInteger + 1, -Limits.MaxInteger - 1 } do
		expect(not votes:cast(userId, 1, "map_b", 2).Ok)
	end
	expect(not votes:cast(42, 2, "map_b", 2).Ok)
	expect(not votes:cast(42, 1, "unknown_map", 2).Ok)
	expect(not votes:cast(42, 1, "map_b", 0 / 0).Ok)
	expect(votes:snapshot().Counts.map_a == 1 and votes:snapshot().Counts.map_b == 0)
end)

test("vote choices and round identities reject malformed input", function()
	local votes = ledger()
	expect(not votes:open(-1, { "map_a" }, 10).Ok)
	expect(not votes:open(0, { "map_a" }, 10).Ok)
	expect(not votes:open(1, { "map_a", "map_a" }, 10).Ok)
	local malformed = (setmetatable({ "map_a" }, {}) :: unknown) :: { string }
	expect(not votes:open(1, malformed, 10).Ok)
	expect(not votes:open(1, { "map_a" }, math.huge).Ok)
	expect(votes:open(1, { "map_a", "map_b" }, 10).Ok)
	local winner = votes:resolve(1, 10)
	expect(winner.Ok and winner.Value == "map_a", "All-zero ties use the injected RNG")
end)

test("boss deadline produces timeout once", function()
	local fixture = machineFixture(true, nil)
	enterActive(fixture)
	fixture.setTime(239)
	fixture.Machine.step()
	expect(#fixture.Outcomes == 0)
	fixture.setTime(240)
	fixture.Machine.step()
	fixture.Machine.bossDefeated()
	fixture.Machine.abort("Aborted")
	expect(#fixture.Outcomes == 1 and fixture.Outcomes[1] == "BossTimeout")
	expect(fixture.Machine.getSnapshot().State == "Resolution")
	expect(fixture.Machine.getSnapshot().EndsAt == 240)
	fixture.Machine.destroy()
	expect(#fixture.Outcomes == 1)
end)

test("boss defeat before deadline owns its celebration interval", function()
	local fixture = machineFixture(true, nil)
	enterActive(fixture)
	fixture.setTime(239)
	fixture.Machine.bossDefeated()
	fixture.Machine.bossDefeated()
	expect(#fixture.Outcomes == 1 and fixture.Outcomes[1] == "BossDefeated")
	expect(fixture.Machine.getSnapshot().EndsAt == 249)
	fixture.setTime(248)
	fixture.Machine.step()
	expect(fixture.Machine.getSnapshot().State == "Resolution")
	fixture.setTime(249)
	fixture.Machine.step()
	expect(fixture.Machine.getSnapshot().State == "Results")
	fixture.Machine.destroy()
end)

test("boss death at deadline cannot replace timeout", function()
	local fixture = machineFixture(true, nil)
	enterActive(fixture)
	fixture.setTime(240)
	fixture.Machine.bossDefeated()
	expect(#fixture.Outcomes == 1 and fixture.Outcomes[1] == "BossTimeout")
	fixture.Machine.destroy()
end)

test("abort and empty server emit one outcome per round", function()
	local fixture = machineFixture(false, nil)
	enterActive(fixture)
	fixture.Machine.abort("NoSurvivors")
	fixture.Machine.abort("Aborted")
	fixture.Machine.setPlayerCount(0)
	fixture.Machine.destroy()
	expect(#fixture.Outcomes == 1 and fixture.Outcomes[1] == "NoSurvivors")
end)

test("fresh loop resumes after the previous round identity", function()
	local first = machineFixture(false, nil)
	expect(first.Machine.getSnapshot().RoundId == 1)
	local lastRound = first.Machine.getSnapshot().RoundId
	first.Machine.destroy()
	local restarted = machineFixture(false, lastRound)
	expect(restarted.Machine.getSnapshot().RoundId == 2)
	enterActive(restarted)
	restarted.setTime(240)
	restarted.Machine.step()
	restarted.Machine.step()
	restarted.setTime(250)
	restarted.Machine.step()
	expect(restarted.Machine.getSnapshot().RoundId == 3)
	restarted.Machine.destroy()
end)

test("results accept Studio identities and exclude nonparticipants", function()
	local options = resultOptions(-1)
	options.Participants = { -1, 42 }
	options.Alive = { 99, 42, -1 }
	options.Stats = {
		{ UserId = 99, Kills = 100, Damage = 1000, Assists = 100 },
		{ UserId = 42, Kills = 2, Damage = 10, Assists = 1 },
		{ UserId = -1, Kills = 2, Damage = 10, Assists = 1 },
	}
	local result = Results.calculate(options)
	expect(#result.Outcome.Survivors == 2 and result.Outcome.Survivors[1] == -1)
	expect(result.Outcome.Survivors[2] == 42 and #result.Stats == 2)
	expect(result.Leaders.Kills == -1 and result.Leaders.Damage == -1 and result.Leaders.Assists == -1)
	options.Alive[1] = 500
	options.Stats[3].Damage = 500
	expect(result.Stats[1].Damage == 10 and result.Outcome.Survivors[1] == -1)
	rejects(function()
		result.Outcome.Survivors[1] = 500
	end)
end)

test("results reject invalid identities in each input collection", function()
	for _, userId in
		{ 0, 0.5, -0.5, 0 / 0, math.huge, -math.huge, Limits.MaxInteger + 1, -Limits.MaxInteger - 1 }
	do
		rejects(function()
			Results.calculate(resultOptions(userId))
		end)
		rejects(function()
			local options = resultOptions(42)
			options.Alive = { userId }
			Results.calculate(options)
		end)
		rejects(function()
			local options = resultOptions(42)
			options.Stats = { { UserId = userId, Kills = 0, Damage = 0, Assists = 0 } }
			Results.calculate(options)
		end)
	end
	for _, roundId in { -1, 0, 0.5, 0 / 0, math.huge } do
		rejects(function()
			local options = resultOptions(42)
			options.RoundId = roundId
			Results.calculate(options)
		end)
	end
end)

print(`Match: {passed} tests passed`)
return passed
