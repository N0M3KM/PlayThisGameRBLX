--!strict
-- Prepared regressions; running them does not establish Studio integration evidence.
local RoundMachine = require("../../../src/shared/Util/Match/RoundMachine")
local States = require("../../../src/shared/Contracts/States")

local function fixture()
	local time = 0
	local outcomes: { States.Outcome } = {}
	local machine = RoundMachine.new({
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
			return true
		end,
	})
	machine.setPlayerCount(1)
	machine.start()
	for _ = 1, 5 do
		machine.step()
	end
	assert(machine.getSnapshot().State == "Active", "Fixture must enter Active")
	return machine, outcomes, function(value: number)
		time = value
	end
end

do
	local machine, outcomes, setTime = fixture()
	setTime(240)
	machine.abort("NoSurvivors")
	machine.bossDefeated()
	assert(#outcomes == 1 and outcomes[1] == "BossTimeout", "Deadline wins simultaneous all-dead/boss death")
	machine.destroy()
	assert(#outcomes == 1, "Teardown must not settle twice")
end

do
	local machine, outcomes, setTime = fixture()
	setTime(239)
	machine.bossDefeated()
	assert(machine.getSnapshot().State == "Resolution", "Early boss defeat starts its celebration")
	machine.abort("NoSurvivors")
	assert(machine.getSnapshot().State == "Intermission", "An empty celebration skips Results")
	assert(#outcomes == 1 and outcomes[1] == "BossDefeated", "Celebration cannot rewrite its settled outcome")
	-- A later round has a distinct settlement identity.
	assert(machine.getSnapshot().RoundId == 2, "Next intermission advances round identity")
	machine.destroy()
end

return 2
